"""Robotic voice processing: each autonomous unit gets its own machine voice.

A clear cloned voice is rebuilt through a role/faction-specific chain — pitch and
formant shift, fixed-pitch channel vocoder, ring modulation, comb resonance, drive and
bit reduction — so every robot sounds synthetic while staying intelligible. Fricatives
above ``air_hz`` are blended back in from the dry voice to keep consonants readable.
"""
import librosa
import numpy as np
from scipy import signal

# Explicit, stable designs. Bastion machines are clean military hardware (metallic ring
# modulation, can resonance), Helix machines are vocoded and glassy, Frontier machines are
# scrap-built and gritty. Within a faction, roles differ in register and mechanism.
ROBOT_VOICES = {
    'bastion/Worker': {'shift': 1.5, 'comb_ms': 3.2, 'comb_fb': .5, 'band': (140, 9000)},
    'bastion/RepairRobot': {'shift': 3.5, 'ring_hz': 110, 'ring_mix': .35, 'comb_ms': 1.6,
                            'comb_fb': .3, 'band': (180, 9500)},
    'bastion/CombatRobot': {'shift': -4, 'ring_hz': 55, 'ring_mix': .35, 'comb_ms': 1.2,
                            'comb_fb': .35, 'drive': 2.0, 'band': (70, 8000)},
    'bastion/Drone': {'vocoder_hz': [165], 'vocoder_mix': .8, 'crush_bits': 11,
                      'band': (260, 9500)},
    'helix/Worker': {'vocoder_hz': [128], 'vocoder_mix': .75, 'comb_ms': 2.4, 'comb_fb': .4,
                     'band': (120, 9000)},
    'helix/RepairRobot': {'shift': 2, 'vocoder_hz': [220, 330], 'vocoder_mix': .6,
                          'chorus': .25, 'band': (200, 10000)},
    'helix/CombatRobot': {'shift': -3, 'vocoder_hz': [72], 'vocoder_mix': .5, 'ring_hz': 61,
                          'ring_mix': .25, 'band': (60, 8500)},
    'helix/Drone': {'shift': 4, 'ring_hz': 290, 'ring_mix': .3, 'crush_bits': 11,
                    'crush_hold': 2, 'band': (300, 10000)},
    'frontier/RepairRobot': {'shift': 2, 'drive': 3.0, 'crush_bits': 10, 'comb_ms': 5.0,
                             'comb_fb': .45, 'band': (250, 6500)},
    'frontier/CombatRobot': {'shift': -5, 'drive': 3.5, 'ring_hz': 33, 'ring_mix': .35,
                             'band': (90, 7000)},
    'frontier/Drone': {'shift': -1.5, 'drive': 2.0, 'tremolo_hz': 23, 'tremolo_depth': .3,
                       'crush_bits': 9, 'crush_hold': 2, 'band': (350, 6000)},
}


def _bandpass(audio, rate, low, high, order=4):
    sos = signal.butter(order, [low, min(high, rate / 2 * .95)], 'bandpass', fs=rate,
                        output='sos')
    return signal.sosfiltfilt(sos, audio)


def _highpass(audio, rate, cutoff, order=4):
    return signal.sosfiltfilt(signal.butter(order, cutoff, 'highpass', fs=rate, output='sos'),
                              audio)


def _vocode(audio, rate, carriers_hz, n_fft=1024, hop=192, lifter=34):
    """Classic fixed-pitch channel vocoder: speech envelope imposed on a buzz carrier."""
    t = np.arange(len(audio)) / rate
    carrier = np.zeros_like(audio)
    for f0 in carriers_hz:
        carrier += signal.sawtooth(2 * np.pi * f0 * t) / len(carriers_hz)
    carrier += np.random.default_rng(len(audio)).normal(0, .04, len(audio))
    speech = librosa.stft(audio, n_fft=n_fft, hop_length=hop)
    buzz = librosa.stft(carrier, n_fft=n_fft, hop_length=hop)

    def envelope(spectrum):
        # Cepstral smoothing keeps formants (the words) and discards the source pitch.
        cepstrum = np.fft.irfft(np.log(np.abs(spectrum) + 1e-7), axis=0)
        cepstrum[lifter:-lifter] = 0
        return np.exp(np.fft.rfft(cepstrum, axis=0).real)

    shaped = buzz / envelope(buzz) * envelope(speech)
    out = librosa.istft(shaped, hop_length=hop, length=len(audio))
    # Silence gating: the carrier must not hum between words.
    gate = np.repeat(np.abs(speech).sum(axis=0), hop)[:len(audio)]
    gate = np.clip(gate / (np.percentile(gate, 95) * .08 + 1e-9), 0, 1)
    gate = np.pad(gate, (0, len(audio) - len(gate)))
    return out * signal.savgol_filter(gate, 101, 2).clip(0, 1)


def _match_rms(audio, reference):
    return audio * (np.sqrt(np.mean(reference ** 2)) / (np.sqrt(np.mean(audio ** 2)) + 1e-9))


def robot_voice(audio, rate, design, air_hz=4200):
    """Process a mono float voice into the robot design; the shift changes its length."""
    dry = np.asarray(audio, dtype=np.float64)
    if design.get('shift'):
        # Tape-speed shift: pitch, formants and tempo move together without the phase
        # smearing of a time-preserving shifter, which blurs consonants. Heavy machines
        # talk lower and slower, small ones higher and quicker.
        dry = librosa.resample(dry, orig_sr=rate, target_sr=rate * 2 ** (-design['shift'] / 12),
                               res_type='soxr_hq')
    voice = dry.copy()
    if design.get('vocoder_hz'):
        mix = design['vocoder_mix']
        voice = (1 - mix) * voice + mix * _match_rms(_vocode(dry, rate, design['vocoder_hz']), dry)
    t = np.arange(len(voice)) / rate
    if design.get('ring_hz'):
        mix = design['ring_mix']
        voice *= (1 - mix) + mix * np.sin(2 * np.pi * design['ring_hz'] * t)
    if design.get('tremolo_hz'):
        voice *= 1 - design['tremolo_depth'] * (.5 + .5 * np.sin(2 * np.pi * design['tremolo_hz'] * t))
    if design.get('comb_ms'):
        delay = max(1, int(rate * design['comb_ms'] / 1000))
        feedback = np.zeros(delay + 1)
        feedback[0], feedback[-1] = 1, -design['comb_fb']
        voice = signal.lfilter([1 - design['comb_fb']], feedback, voice)
    if design.get('chorus'):
        lfo = (.006 + .002 * np.sin(2 * np.pi * .8 * t)) * rate
        index = np.clip(np.arange(len(voice)) - lfo, 0, len(voice) - 1)
        voice += design['chorus'] * np.interp(index, np.arange(len(voice)), voice)
    voice = _match_rms(voice, dry)
    if design.get('drive'):
        peak = np.max(np.abs(voice)) + 1e-9
        voice = np.tanh(design['drive'] * voice / peak) / np.tanh(design['drive']) * peak
    if design.get('crush_bits'):
        hold = design.get('crush_hold', 1)
        held = np.repeat(voice[::hold], hold)[:len(voice)]
        peak = np.max(np.abs(held)) + 1e-9
        steps = 2 ** (design['crush_bits'] - 1)
        voice = np.round(held / peak * steps) / steps * peak
    voice = _bandpass(voice, rate, *design['band'])
    # Consonant air from the dry voice keeps s/t/k readable through heavy processing.
    if air_hz < design['band'][1]:
        voice += .45 * _highpass(dry, rate, air_hz)
    return voice
