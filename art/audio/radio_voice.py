"""Light battlefield comms colouring for crew speech, chosen by unit class and faction.

Parallel processing: the radio path (band limit, handset presence peak, saturation or codec
grit, a breath of static) is blended with the full-band voice, so lines read as field
comms without losing the consonants that make words clear. The radio path never closes
below 4.3 kHz; the dry share keeps the rest.
"""
import numpy as np
from scipy import signal

# Channel per unit class: (low Hz, high Hz, presence Hz, presence dB, drive, wet, cab ms).
CHANNELS = {
    'infantry': (250, 5500, 2200, 3.0, 1.6, .65, 0),   # field handset
    'sniper': (220, 6000, 2400, 2.0, 1.3, .5, 0),      # throat mic, hushed
    'commander': (150, 7500, 2600, 2.0, 1.2, .4, 0),   # command net, cleanest
    'armor': (200, 5000, 2000, 3.0, 2.0, .65, 2.6),    # helmet intercom inside steel
    'air': (300, 5200, 2800, 4.0, 1.8, .7, 0),         # pilot headset
    'logistics': (300, 4800, 1900, 3.0, 2.4, .7, 0),   # CB radio
}
UNIT_CLASS = {
    'Infantry': 'infantry', 'RocketInfantry': 'infantry', 'AssaultInfantry': 'infantry',
    'SniperInfantry': 'sniper', 'Hero': 'commander', 'Tank': 'armor', 'AdvancedTank': 'armor',
    'Helicopter': 'air', 'EvacTransport': 'air', 'SupplyTruck': 'logistics', 'Worker': 'logistics',
}
# Faction gear: Bastion analog military, Helix digital codec, Frontier older and rougher.
GEAR = {
    'bastion': {'drive': 1.0, 'bits': None, 'low': 0, 'high': 0, 'static_db': -40},
    'helix': {'drive': 0., 'bits': 11, 'low': -30, 'high': 600, 'static_db': None},
    'frontier': {'drive': 1.4, 'bits': None, 'low': 50, 'high': -500, 'static_db': -36},
}


def _peaking(rate, freq, gain_db, q=1.0):
    a = 10 ** (gain_db / 40)
    w = 2 * np.pi * freq / rate
    alpha = np.sin(w) / (2 * q)
    b = [1 + alpha * a, -2 * np.cos(w), 1 - alpha * a]
    den = [1 + alpha / a, -2 * np.cos(w), 1 - alpha / a]
    return np.array(b) / den[0], np.array(den) / den[0]


def radio(audio, rate, faction, role, seed=0):
    low, high, presence, boost, drive, wet, cab = CHANNELS[UNIT_CLASS[role]]
    gear = GEAR[faction]
    low, high = low + gear['low'], max(4300, high + gear['high'])
    dry = np.asarray(audio, dtype=np.float64)
    path = signal.sosfiltfilt(signal.butter(4, [low, high], 'bandpass', fs=rate, output='sos'), dry)
    path = signal.lfilter(*_peaking(rate, presence, boost), path)
    if cab:
        delay = int(rate * cab / 1000)
        path = path + .18 * np.concatenate([np.zeros(delay), path[:-delay]])
    level = np.max(np.abs(path)) + 1e-9
    drive *= gear['drive']
    if drive:
        path = np.tanh(drive * path / level) / np.tanh(drive) * level
    if gear['bits']:
        steps = 2 ** (gear['bits'] - 1)
        path = np.round(path / level * steps) / steps * level
    if gear['static_db'] is not None:
        # Static rides the speech envelope, so it never hisses between words.
        envelope = signal.savgol_filter(np.abs(dry), int(.02 * rate) | 1, 1).clip(0)
        hiss = np.random.default_rng(seed).normal(0, 1, len(dry))
        hiss = signal.sosfiltfilt(signal.butter(2, [1500, min(high, 6500)], 'bandpass', fs=rate,
                                                output='sos'), hiss)
        rms = np.sqrt(np.mean(dry ** 2))
        path = path + hiss * envelope / (envelope.max() + 1e-9) * rms * 10 ** (gear['static_db'] / 20) * 3
    path *= np.sqrt(np.mean(dry ** 2)) / (np.sqrt(np.mean(path ** 2)) + 1e-9)
    return wet * path + (1 - wet) * dry
