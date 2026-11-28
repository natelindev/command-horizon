#!/usr/bin/env python3
"""Render studio-grade, deterministic combat Foley/synthesis; requires Python + NumPy + SciPy.

Uses physically informed ballistic shockwaves (asymmetric N-waves), time-varying
resonant spectral sweeps, granular combustion crackle, transformer-style warm
saturation, and diffuse frequency-dependent outdoor terrain reflections.
No samples, models, network access, or third-party recordings are used.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import wave

import numpy as np
from scipy import signal

RATE = 48000
PEAK = 10.0 ** (-3.2 / 20.0)
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/audio/combat"
HERE = Path(__file__).resolve().parent


def clock(seconds: float) -> np.ndarray:
    return np.arange(round(seconds * RATE), dtype=np.float64) / RATE


def filter_band(sig: np.ndarray, low: float, high: float, order: float = 4.0) -> np.ndarray:
    """Zero-phase smooth spectral band filter without startup ringing."""
    count = len(sig)
    freqs = np.fft.rfftfreq(count, 1.0 / RATE)
    spec = np.fft.rfft(sig)
    hp = 1.0 - np.exp(-((freqs / max(low, 1.0)) ** order)) if low > 0.0 else 1.0
    lp = np.exp(-((freqs / max(high, 20.0)) ** order)) if high < RATE * 0.49 else 1.0
    return np.fft.irfft(spec * hp * lp, n=count)


def noise(t: np.ndarray, rng: np.random.Generator, low: float, high: float) -> np.ndarray:
    """Smooth-band random noise normalized by RMS."""
    shaped = filter_band(rng.standard_normal(len(t)), low, high)
    return shaped / max(float(np.sqrt(np.mean(shaped * shaped))), 1e-8)


def pink_noise(n: int, rng: np.random.Generator, low: float = 25.0, high: float = 16000.0) -> np.ndarray:
    """1/f-weighted organic broadband noise (warmer and far less papery than white noise)."""
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    spec = np.fft.rfft(rng.standard_normal(n))
    pink = 1.0 / np.maximum(freqs, 20.0) ** 0.55
    pink[0] = 0.0
    hp = 1.0 - np.exp(-((freqs / max(low, 1.0)) ** 4.0))
    lp = np.exp(-((freqs / max(high, 40.0)) ** 4.0))
    sig = np.fft.irfft(spec * pink * hp * lp, n=n)
    return sig / max(float(np.sqrt(np.mean(sig * sig))), 1e-8)


def dynamic_lowpass(sig: np.ndarray, start_hz: float, end_hz: float, decay_s: float) -> np.ndarray:
    """Time-varying lowpass sweep via multi-band crossfading (models cooling blast/muzzle gas)."""
    n = len(sig)
    t = np.arange(n, dtype=np.float64) / RATE
    # Four logarithmically spaced filter bands blended continuously over time.
    cuts = np.geomspace(max(end_hz, 40.0), min(start_hz, RATE * 0.46), 4)
    bands = [filter_band(sig, 20.0, float(c), order=3.0) for c in cuts]
    pos = np.clip(np.exp(-t / max(decay_s, 1e-4)), 0.0, 1.0) * 3.0
    out = np.zeros(n, dtype=np.float64)
    for idx in range(3):
        mask = (pos >= idx) & (pos <= idx + 1.0)
        frac = np.clip(pos - idx, 0.0, 1.0)
        w = np.where(mask, frac, 0.0)
        if idx == 0:
            out += np.where(pos <= 1.0, bands[0] * (1.0 - w) + bands[1] * w, 0.0)
        elif idx == 1:
            out += np.where((pos > 1.0) & (pos <= 2.0), bands[1] * (1.0 - w) + bands[2] * w, 0.0)
        else:
            out += np.where(pos > 2.0, bands[2] * (1.0 - w) + bands[3] * w, 0.0)
    return out


def crackle_bed(
    t: np.ndarray,
    rng: np.random.Generator,
    density: float,
    low_hz: float,
    high_hz: float,
    decay_s: float,
    attack_s: float = 0.002,
    amp_decay_s: float = 0.0035,
) -> np.ndarray:
    """Granular stochastic combustion / spark / shrapnel crackle (replaces sterile white noise)."""
    n = len(t)
    env = envelope(t, decay_s, attack_s)
    # Sparse impulsive bursts weighted by the macro envelope
    probs = np.clip(density * env / RATE, 0.0, 0.45)
    hits = rng.random(n) < probs
    impulses = np.zeros(n, dtype=np.float64)
    count = int(hits.sum())
    if count > 0:
        # Heavy-tailed amplitude distribution creates natural loud pops + fine sizzle
        mags = (rng.exponential(0.55, count) + 0.15) * rng.choice([-1.0, 1.0], count)
        impulses[hits] = mags * env[hits]
    # Short resonant grain kernel
    k_len = max(16, round(amp_decay_s * 6.0 * RATE))
    tk = np.arange(k_len, dtype=np.float64) / RATE
    kernel = rng.standard_normal(k_len) * np.exp(-tk / max(amp_decay_s, 1e-4))
    kernel = filter_band(kernel, low_hz, high_hz, order=3.0)
    kernel /= max(float(np.sqrt(np.sum(kernel * kernel))), 1e-8)
    fft_n = 1 << (n + k_len - 1).bit_length()
    out = np.fft.irfft(np.fft.rfft(impulses, n=fft_n) * np.fft.rfft(kernel, n=fft_n), n=fft_n)[:n]
    rms = float(np.sqrt(np.mean(out * out)))
    return out / max(rms, 1e-6) * float(np.sqrt(np.mean(env * env)))


def n_wave(t: np.ndarray, duration_s: float, ring_hz: float = 0.0) -> np.ndarray:
    """Ballistic Friedlander / N-wave pressure shock front (authentic supersonic crack)."""
    u = t / max(duration_s, 1e-5)
    # Sharp positive overpressure peak followed by negative rarefaction phase
    wave_sig = (1.0 - u) * np.exp(-u * 2.2) * (1.0 - np.exp(-t / (duration_s * 0.08)))
    if ring_hz > 0.0:
        wave_sig += 0.28 * np.sin(2.0 * np.pi * ring_hz * t) * np.exp(-u * 1.9)
    return wave_sig


def envelope(t: np.ndarray, decay: float, attack: float = 0.0008) -> np.ndarray:
    return (1.0 - np.exp(-t / max(attack, 1e-5))) * np.exp(-t / max(decay, 1e-5))


def sweep(t: np.ndarray, start: float, end: float, decay: float, phase_offset: float = 0.0) -> np.ndarray:
    phase = 2.0 * np.pi * (end * t + (start - end) * decay * (1.0 - np.exp(-t / decay))) + phase_offset
    return np.sin(phase)


def fm_sweep(
    t: np.ndarray,
    start: float,
    end: float,
    decay: float,
    mod_ratio: float = 1.5,
    mod_index: float = 2.2,
    mod_decay: float = 0.04,
) -> np.ndarray:
    base_phase = 2.0 * np.pi * (end * t + (start - end) * decay * (1.0 - np.exp(-t / decay)))
    mod_env = mod_index * np.exp(-t / max(mod_decay, 1e-4))
    return np.sin(base_phase + mod_env * np.sin(base_phase * mod_ratio))


def saturate(sig: np.ndarray, drive: float = 1.8) -> np.ndarray:
    """Transformer/tape-style asymmetric harmonic saturation for warm, expensive punch."""
    driven = sig * drive
    # Soft even + odd harmonic shaping without harsh digital buzz
    shaped = np.tanh(driven + 0.12 * driven * driven / (1.0 + np.abs(driven)))
    return shaped - shaped.mean()


def bus_glue(sig: np.ndarray, threshold: float = 0.35, ratio: float = 3.2, attack_ms: float = 1.5, release_ms: float = 45.0) -> np.ndarray:
    """Gentle feed-forward dynamics compressor that gives weapons & blasts cohesive weight."""
    abs_sig = np.abs(sig)
    # Smooth envelope detector via fast IIR lowpass approximation
    win_rel = max(3, round(release_ms * 0.001 * RATE))
    b_rel = [1.0 / win_rel]
    a_rel = [1.0, -(1.0 - 1.0 / win_rel)]
    env = signal.lfilter(b_rel, a_rel, abs_sig)
    # Preserve initial micro-transient punch
    win_att = max(2, round(attack_ms * 0.001 * RATE))
    b_att = [1.0 / win_att]
    a_att = [1.0, -(1.0 - 1.0 / win_att)]
    env = np.maximum(env, signal.lfilter(b_att, a_att, abs_sig) * 0.65)
    over = np.maximum(env / max(threshold, 1e-4), 1.0)
    gain = over ** (1.0 / ratio - 1.0)
    return sig * gain


def add_at(target: np.ndarray, event: np.ndarray, seconds: float, gain: float = 1.0) -> None:
    offset = round(seconds * RATE)
    if offset < 0:
        return
    count = min(len(event), len(target) - offset)
    if count > 0:
        target[offset : offset + count] += event[:count] * gain


def resonances(
    t: np.ndarray,
    frequencies: list[float],
    decay: float,
    attack: float = 0.0004,
    rolloff: float = 0.72,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    out = np.zeros_like(t)
    for index, frequency in enumerate(frequencies):
        mode_decay = decay / (1.0 + index * 0.36)
        phase = float(rng.uniform(0.0, 2.0 * np.pi)) if rng is not None else index * 0.71
        out += np.sin(2.0 * np.pi * frequency * t + phase) * np.exp(-t / mode_decay) * (rolloff ** index)
    return out * (1.0 - np.exp(-t / attack))


def outdoor_tail(
    dry: np.ndarray,
    rng: np.random.Generator,
    wet: float = 0.24,
    decay: float = 0.22,
    bright_hz: float = 1800.0,
    predelay: float = 0.014,
) -> np.ndarray:
    """Physically modeled outdoor battlefield reflection tail via multi-band FFT convolution.

    Models ground early reflection, mid-distance terrain slapback, and warm air-absorbed
    horizon roll-off where highs dissipate quickly while low-mid body lingers.
    """
    n = len(dry)
    ir_len = min(n, round(max(decay * 4.5, 0.20) * RATE))
    t_ir = np.arange(ir_len, dtype=np.float64) / RATE
    # Early ground/structure reflections (sparse natural taps)
    early_imp = np.zeros(ir_len, dtype=np.float64)
    for tap_s, tap_g in [
        (predelay, 0.75),
        (predelay * 1.85, 0.52),
        (predelay * 3.1, 0.38),
        (predelay * 4.9, 0.26),
        (predelay * 7.2, 0.16),
    ]:
        idx = round(tap_s * rng.uniform(0.88, 1.12) * RATE)
        if 0 <= idx < ir_len:
            early_imp[idx] += tap_g * rng.choice([-1.0, 1.0])
    early = filter_band(early_imp, 160.0, bright_hz * 1.35, order=2.5)
    # Diffused mid & warm sub-valley scatter with progressive air absorption
    mid_scatter = filter_band(rng.standard_normal(ir_len), 180.0, bright_hz * 0.95) * np.exp(-t_ir / max(decay * 0.45, 0.02))
    warm_valley = filter_band(rng.standard_normal(ir_len), 40.0, min(bright_hz * 0.36, 460.0)) * np.exp(-t_ir / max(decay * 1.15, 0.05))
    ir = 0.48 * early + 0.42 * mid_scatter + 0.85 * warm_valley
    start_idx = min(ir_len - 1, round(predelay * 0.85 * RATE))
    ir[:start_idx] = 0.0
    ramp = min(round(0.005 * RATE), ir_len - start_idx)
    if ramp > 0:
        ir[start_idx : start_idx + ramp] *= np.linspace(0.0, 1.0, ramp)
    norm = float(np.sqrt(np.sum(ir * ir)))
    if norm > 1e-9:
        ir /= norm
    fft_n = 1 << (n + ir_len - 1).bit_length()
    conv = np.fft.irfft(np.fft.rfft(dry, n=fft_n) * np.fft.rfft(ir, n=fft_n), n=fft_n)[:n]
    return dry + conv * wet


def ballistic_blast(t: np.ndarray, rng: np.random.Generator, weight: float = 1.0, p: float = 1.0) -> np.ndarray:
    """Multi-stage ballistic concussion: Friedlander shockwave, cooling gas sweep, chest punch, sub."""
    # 1. Supersonic Friedlander N-wave shock front (authentic crack without white-noise fizz)
    shock = n_wave(t, 0.0022 * (weight ** 0.45), ring_hz=1100.0 * p / (weight ** 0.35))
    shock = filter_band(shock, 180.0, 14500.0, order=2.5)
    # 2. Rapidly cooling muzzle/blast gas (pink noise swept dynamically from bright to dark)
    gas_raw = pink_noise(len(t), rng, 55.0, 13000.0) * envelope(t, 0.068 * weight, 0.0002)
    gas = dynamic_lowpass(gas_raw, start_hz=9500.0 / (weight ** 0.25), end_hz=320.0, decay_s=0.026 * weight)
    # 3. Granular gunpowder/detonation crackle (gives tactile realism and grit)
    crackle = crackle_bed(t, rng, density=4200.0 / (weight ** 0.2), low_hz=450.0, high_hz=8200.0,
                          decay_s=0.052 * weight, attack_s=0.0005, amp_decay_s=0.0022)
    # 4. Saturated low-mid chest thump (audible weight on headphones AND laptop speakers)
    chest_f0 = 185.0 * p / (weight ** 0.55)
    chest_f1 = 44.0 * p / (weight ** 0.45)
    chest = saturate(
        (sweep(t, chest_f0, chest_f1, 0.032 * weight)
         + 0.38 * sweep(t, chest_f0 * 1.92, chest_f1 * 1.85, 0.022 * weight, 0.6))
        * envelope(t, 0.088 * weight, 0.0003),
        2.1,
    )
    # 5. Deep, tight sub-bass pressure wave
    sub = sweep(t, 76.0 / (weight ** 0.45), 28.0 / (weight ** 0.32), 0.075 * weight) * envelope(t, 0.16 * weight, 0.0007)
    # 6. Warm turbulent combustion air tail
    body = pink_noise(len(t), rng, 42.0, 620.0) * envelope(t, 0.095 * weight, 0.003)
    return 0.78 * shock + 0.85 * gas + 0.38 * crackle + 0.66 * chest + 0.52 * sub + 0.46 * body


def synthesize(name: str, duration: float, seed: int) -> np.ndarray:
    t = clock(duration)
    rng = np.random.default_rng(seed)
    p = rng.uniform(0.945, 1.055)  # Physical per-take variation
    out = np.zeros_like(t)

    if name == "rifle_fire":
        # Tactile modern assault carbine: tight supersonic crack, punchy 300-1800 Hz bark, crisp bolt.
        whip = n_wave(t, 0.0012, ring_hz=2450.0 * p) * 0.95
        muzzle_raw = pink_noise(len(t), rng, 140.0, 15000.0) * envelope(t, 0.026, 0.00012)
        muzzle = dynamic_lowpass(muzzle_raw, start_hz=11500.0, end_hz=680.0, decay_s=0.011)
        chamber = saturate(
            sweep(t, 295.0 * p, 96.0 * p, 0.014) * envelope(t, 0.024, 0.00015)
            + 0.55 * filter_band(muzzle_raw, 180.0, 1400.0),
            2.4,
        )
        crackle = crackle_bed(t, rng, density=6200.0, low_hz=900.0, high_hz=11500.0,
                              decay_s=0.018, attack_s=0.0002, amp_decay_s=0.0012)
        out = 0.75 * whip + 0.78 * muzzle + 0.62 * chamber + 0.34 * crackle
        # Authentic steel bolt-carrier mechanical snap (subtle, crisp, tight)
        bolt = (
            0.52 * filter_band(n_wave(t, 0.0007), 1200.0, 9500.0)
            + 0.48 * resonances(t, [1820.0 * p, 3490.0 * p, 5840.0 * p], 0.0075, rng=rng)
        )
        add_at(out, bolt, 0.029 * rng.uniform(0.90, 1.10), 0.16)
        out = outdoor_tail(out, rng, wet=0.19, decay=0.13, bright_hz=2200.0, predelay=0.010)

    elif name == "autocannon_fire":
        # Heavy 30mm chain-gun: brutal tight metallic punch, resonant barrel bark, breech slam.
        core = ballistic_blast(t, rng, weight=0.72, p=p)
        breech = saturate(
            sweep(t, 240.0 * p, 68.0 * p, 0.024) * envelope(t, 0.045, 0.0002)
            + 0.42 * resonances(t, [198.0 * p, 485.0 * p, 1140.0 * p, 2280.0 * p], 0.022, rng=rng),
            2.2,
        )
        # Heavy metallic receiver/feeder clank
        clank = (
            0.48 * pink_noise(len(t), rng, 650.0, 5200.0) * envelope(t, 0.0085, 0.00018)
            + 0.52 * resonances(t, [960.0 * p, 2190.0 * p, 4120.0 * p], 0.014, rng=rng)
        )
        out = 0.88 * core + 0.52 * breech
        add_at(out, clank, 0.046 * rng.uniform(0.92, 1.08), 0.19)
        out = outdoor_tail(out, rng, wet=0.22, decay=0.17, bright_hz=1900.0, predelay=0.012)

    elif name == "cannon_fire":
        # 120mm MBT cannon: visceral breech slam, tearing shockwave, huge chest punch, valley roll.
        blast = ballistic_blast(t, rng, weight=1.45, p=p)
        # Mechanical steel recoil/breech impact right at t=0
        breech_thump = saturate(
            sweep(t, 168.0 * p, 38.0 * p, 0.062) * envelope(t, 0.15, 0.00025)
            + 0.36 * resonances(t, [142.0 * p, 338.0 * p, 790.0 * p], 0.052, rng=rng),
            2.5,
        )
        # Deep cinematic low-end bloom + cooling cannon roar
        sub_bloom = sweep(t, 66.0 * p, 24.0 * p, 0.13) * envelope(t, 0.34, 0.001)
        roar_raw = pink_noise(len(t), rng, 34.0, 2600.0) * envelope(t, 0.24, 0.004)
        roar = dynamic_lowpass(roar_raw, start_hz=3200.0, end_hz=190.0, decay_s=0.085)
        crackle = crackle_bed(t, rng, density=3200.0, low_hz=280.0, high_hz=4800.0,
                              decay_s=0.16, attack_s=0.002, amp_decay_s=0.0045)
        out = 0.92 * blast + 0.65 * breech_thump + 0.58 * sub_bloom + 0.55 * roar + 0.30 * crackle
        # Subtle metallic casing / hydraulic recoil recovery hiss
        vent = pink_noise(len(t), rng, 950.0, 5200.0) * envelope(t, 0.075, 0.012)
        add_at(out, vent, 0.088, 0.09)
        out = outdoor_tail(out, rng, wet=0.38, decay=0.44, bright_hz=1200.0, predelay=0.016)
        # Distant canyon bass roll
        distant = pink_noise(len(t), rng, 28.0, 220.0) * envelope(t, 0.48, 0.055)
        out += 0.24 * distant

    elif name == "energy_fire":
        # Helix magnetic-containment plasma lance: crisp arc snap + warm sub pulse + lush glassy harmonic beam.
        # Avoids cheesy FM "pew-zap" buzz in favor of focused high-tech energy acoustics.
        arc_snap = filter_band(n_wave(t, 0.0009, ring_hz=3800.0 * p), 1400.0, 15000.0) * 0.72
        # Warm magnetic-containment low thump (gives real physical weight to plasma shots!)
        mag_thump = saturate(
            sweep(t, 220.0 * p, 56.0 * p, 0.028) * envelope(t, 0.058, 0.00025),
            1.7,
        )
        # Focused harmonic plasma core: clean descending fifth + octave chord with silky phase glide
        core_f = 520.0 * p
        beam = (
            0.52 * sweep(t, core_f * 2.1, core_f * 0.62, 0.032)
            + 0.34 * sweep(t, core_f * 3.15, core_f * 0.93, 0.026, 0.8)
            + 0.20 * sweep(t, core_f * 4.2, core_f * 1.24, 0.021, 1.9)
        ) * envelope(t, 0.054, 0.0005)
        # Delicate high-voltage ion shimmer (filtered granular sparks, never harsh buzz)
        ion_shimmer = crackle_bed(t, rng, density=4800.0, low_hz=2600.0, high_hz=12500.0,
                                  decay_s=0.058, attack_s=0.001, amp_decay_s=0.0016)
        glass_tail = resonances(t, [680.0 * p, 1020.0 * p, 2040.0 * p, 3060.0 * p], 0.048, rolloff=0.62, rng=rng)
        out = 0.62 * arc_snap + 0.68 * mag_thump + 0.56 * beam + 0.26 * ion_shimmer + 0.22 * glass_tail
        out = outdoor_tail(out, rng, wet=0.18, decay=0.10, bright_hz=3000.0, predelay=0.008)

    elif name == "rail_fire":
        # Hypersonic EM railgun: violent capacitor crack, Mach whip-boom, vacuum sub-collapse, taut titanium ring.
        cap_crack = n_wave(t, 0.0011, ring_hz=4400.0 * p) * 0.92
        # Supersonic air-tear whip (rapid downward resonant sweep + filtered crackle)
        mach_raw = pink_noise(len(t), rng, 110.0, 16000.0) * envelope(t, 0.052, 0.00015)
        mach_tear = dynamic_lowpass(mach_raw, start_hz=14000.0, end_hz=420.0, decay_s=0.022)
        boom_core = saturate(
            sweep(t, 420.0 * p, 48.0 * p, 0.026) * envelope(t, 0.072, 0.00018)
            + 0.45 * sweep(t, 840.0 * p, 96.0 * p, 0.018, 0.5) * envelope(t, 0.045, 0.00018),
            2.3,
        )
        # Deep vacuum collapse sub-impulse
        vac_sub = sweep(t, 128.0 * p, 32.0 * p, 0.048) * envelope(t, 0.12, 0.0005)
        # Cold taut titanium rail discharge harmonic ring (clean musical overtones, not tinny)
        rail_ring = resonances(t, [740.0 * p, 1485.0 * p, 2960.0 * p, 4450.0 * p], 0.095, rolloff=0.58, rng=rng)
        em_spark = crackle_bed(t, rng, density=4500.0, low_hz=2200.0, high_hz=14000.0,
                               decay_s=0.055, attack_s=0.0005, amp_decay_s=0.0018)
        out = 0.85 * cap_crack + 0.68 * mach_tear + 0.64 * boom_core + 0.58 * vac_sub + 0.24 * rail_ring + 0.26 * em_spark
        out = outdoor_tail(out, rng, wet=0.25, decay=0.21, bright_hz=2500.0, predelay=0.011)

    elif name == "missile_launch":
        # Pneumatic canister THOOM + fierce crackling rocket igniter + Doppler-sweeping motor roar.
        tube_pop = saturate(
            sweep(t, 285.0 * p, 72.0 * p, 0.024) * envelope(t, 0.045, 0.00025)
            + 0.45 * n_wave(t, 0.0028, ring_hz=640.0 * p),
            1.9,
        )
        # Fierce crackling solid-fuel ignition (granular sparks + rushing propellant)
        igniter = crackle_bed(t, rng, density=7500.0, low_hz=750.0, high_hz=12500.0,
                              decay_s=0.14, attack_s=0.004, amp_decay_s=0.0028)
        # Doppler-darkening turbulent rocket plume (starts bright and fierce, shifts lower as missile speeds away)
        plume_raw = pink_noise(len(t), rng, 55.0, 11000.0) * envelope(t, 0.21, 0.014)
        plume = dynamic_lowpass(plume_raw, start_hz=8800.0, end_hz=650.0, decay_s=0.13)
        # Subtle chaotic thruster flutter (non-periodic multi-rate modulation)
        flutter = (
            0.76
            + 0.14 * np.sin(2.0 * np.pi * (47.0 * p) * t + 0.9 * np.sin(2.0 * np.pi * 11.3 * t))
            + 0.10 * np.sin(2.0 * np.pi * (73.0 * p) * t + 1.4)
        )
        plume_sub = pink_noise(len(t), rng, 38.0, 290.0) * envelope(t, 0.25, 0.012)
        doppler_body = sweep(t, 290.0 * p, 82.0 * p, 0.16) * envelope(t, 0.18, 0.010)
        out = 0.78 * tube_pop + 0.56 * igniter + 0.74 * plume * flutter + 0.48 * plume_sub + 0.16 * doppler_body
        out = outdoor_tail(out, rng, wet=0.20, decay=0.18, bright_hz=2000.0, predelay=0.013)

    elif name == "impact_light":
        # Kinetic armor hit / ballistic deflection: crisp impact crack, tight punch, authentic steel deflection ping.
        crack = n_wave(t, 0.0008, ring_hz=2900.0 * p) * 0.65
        thud = saturate(
            sweep(t, 235.0 * p, 78.0 * p, 0.014) * envelope(t, 0.025, 0.0002)
            + 0.52 * pink_noise(len(t), rng, 120.0, 2200.0) * envelope(t, 0.016, 0.0003),
            2.0,
        )
        # Brief subtle metallic armor ping (never cartoony)
        ping = (
            0.22 * sweep(t, 2850.0 * p, 2250.0 * p, 0.014) * envelope(t, 0.020, 0.0002)
            + 0.18 * resonances(t, [890.0 * p, 2040.0 * p, 4180.0 * p], 0.022, rolloff=0.62, rng=rng)
        )
        out = 0.58 * crack + 0.68 * thud + ping

    elif name == "impact_heavy":
        # Cinematic HE warhead detonation: sharp overpressure shock, saturated fireball crunch, rolling bass, shrapnel.
        blast = ballistic_blast(t, rng, weight=1.95, p=p)
        shock_core = saturate(
            sweep(t, 124.0 * p, 26.0 * p, 0.095) * envelope(t, 0.25, 0.00035)
            + 0.52 * pink_noise(len(t), rng, 34.0, 520.0) * envelope(t, 0.30, 0.004),
            2.4,
        )
        fireball_raw = pink_noise(len(t), rng, 85.0, 5500.0) * envelope(t, 0.24, 0.009)
        fireball = dynamic_lowpass(fireball_raw, start_hz=4800.0, end_hz=260.0, decay_s=0.11)
        crackle = crackle_bed(t, rng, density=4200.0, low_hz=420.0, high_hz=7800.0,
                              decay_s=0.22, attack_s=0.003, amp_decay_s=0.0042)
        out = 0.90 * blast + 0.66 * shock_core + 0.52 * fireball + 0.38 * crackle
        # Organic randomized dirt clods & shrapnel scatter
        for delay, gain in [(0.058, 0.20), (0.128, 0.17), (0.215, 0.14), (0.335, 0.10), (0.485, 0.06)]:
            dt = delay * rng.uniform(0.84, 1.16)
            grit = (
                0.65 * pink_noise(len(t), rng, 450.0, 5800.0) * envelope(t, 0.017, 0.00035)
                + 0.35 * resonances(t, [720.0 * rng.uniform(0.75, 1.35), 1850.0 * rng.uniform(0.75, 1.35)], 0.020, rng=rng)
            )
            add_at(out, grit, dt, gain)
        out = outdoor_tail(out, rng, wet=0.40, decay=0.48, bright_hz=1100.0, predelay=0.018)
        out += 0.26 * pink_noise(len(t), rng, 26.0, 210.0) * envelope(t, 0.56, 0.036)

    elif name == "infantry_fall":
        # Grounded tactical kit/boot thud + fabric settle (clean, crisp, non-gory).
        thud = (
            0.65 * pink_noise(len(t), rng, 55.0, 440.0) * envelope(t, 0.038, 0.002)
            + 0.35 * sweep(t, 138.0 * p, 46.0 * p, 0.018) * envelope(t, 0.042, 0.0008)
        )
        cloth = 0.18 * pink_noise(len(t), rng, 520.0, 3200.0) * envelope(t, 0.058, 0.010)
        out = thud + cloth
        for delay, gain in [(0.048, 0.18), (0.108, 0.11), (0.176, 0.05)]:
            tap = (
                0.70 * pink_noise(len(t), rng, 340.0, 2600.0) * envelope(t, 0.010, 0.00035)
                + 0.30 * resonances(t, [490.0 * p, 1180.0 * p, 2260.0 * p], 0.014, rng=rng)
            )
            add_at(out, tap, delay * rng.uniform(0.9, 1.1), gain)

    elif name == "vehicle_destroy":
        # Armored hull breach + primary fuel/ammo blast + secondary cook-off + tearing steel + heavy debris.
        blast = ballistic_blast(t, rng, weight=1.90, p=p)
        hull_boom = saturate(
            sweep(t, 96.0 * p, 22.0 * p, 0.14) * envelope(t, 0.40, 0.0005)
            + 0.48 * pink_noise(len(t), rng, 30.0, 580.0) * envelope(t, 0.36, 0.009),
            2.3,
        )
        # Tearing armor plate groan (dark filtered inharmonic stress)
        shear_raw = (
            fm_sweep(t, 240.0 * p, 98.0 * p, 0.19, mod_ratio=2.41, mod_index=2.1, mod_decay=0.14)
            * envelope(t, 0.24, 0.018)
        )
        shear = filter_band(shear_raw, 120.0, 2400.0, order=2.5)
        crackle = crackle_bed(t, rng, density=4600.0, low_hz=420.0, high_hz=8600.0,
                              decay_s=0.34, attack_s=0.004, amp_decay_s=0.0048)
        out = 0.90 * blast + 0.65 * hull_boom + 0.22 * shear + 0.36 * crackle
        # Violent secondary ammo cook-off pop
        cookoff = ballistic_blast(t, rng, weight=0.92, p=p * 1.08)
        add_at(out, cookoff, 0.132 * rng.uniform(0.88, 1.12), 0.40)
        # Heavy metallic wreckage plates tumbling & clanging
        for delay, gain, pitch in [
            (0.082, 0.24, 295),
            (0.195, 0.19, 205),
            (0.330, 0.15, 425),
            (0.495, 0.11, 260),
            (0.690, 0.07, 540),
            (0.910, 0.045, 340),
        ]:
            debris = (
                0.45 * pink_noise(len(t), rng, 320.0, 3800.0) * envelope(t, 0.020, 0.00035)
                + 0.55 * resonances(t, [pitch * p, pitch * 2.57 * p, pitch * 4.11 * p], 0.072, rolloff=0.66, rng=rng)
            )
            add_at(out, debris, delay * rng.uniform(0.90, 1.10), gain)
        out = outdoor_tail(out, rng, wet=0.40, decay=0.58, bright_hz=1050.0, predelay=0.020)
        out += 0.24 * pink_noise(len(t), rng, 24.0, 195.0) * envelope(t, 0.68, 0.042)

    elif name == "structure_destroy":
        # Monumental seismic collapse: foundation detonation, cascading masonry fractures, girder groans, rubble.
        blast = ballistic_blast(t, rng, weight=2.15, p=p)
        seismic = saturate(
            sweep(t, 64.0 * p, 18.0 * p, 0.22) * envelope(t, 0.64, 0.0012)
            + 0.50 * pink_noise(len(t), rng, 24.0, 310.0) * envelope(t, 0.52, 0.022),
            2.2,
        )
        # Deep structural steel groan
        girder = filter_band(
            fm_sweep(t, 165.0 * p, 68.0 * p, 0.38, mod_ratio=1.73, mod_index=1.8, mod_decay=0.28)
            * envelope(t, 0.45, 0.045),
            80.0, 1400.0, order=2.5,
        )
        out = 0.80 * blast + 0.68 * seismic + 0.22 * girder
        # Cascading masonry/concrete slabs collapsing
        for delay, gain, size in [
            (0.075, 0.34, 1.15),
            (0.185, 0.36, 0.96),
            (0.320, 0.30, 1.04),
            (0.495, 0.24, 0.86),
            (0.700, 0.19, 0.74),
            (0.940, 0.13, 0.62),
            (1.220, 0.08, 0.54),
        ]:
            chunk_raw = pink_noise(len(t), rng, 65.0, 3200.0) * envelope(t, 0.068 * size, 0.001)
            chunk = (
                0.70 * dynamic_lowpass(chunk_raw, start_hz=2800.0, end_hz=320.0, decay_s=0.055 * size)
                + 0.34 * sweep(t, 190.0 * p, 48.0 * p, 0.030) * envelope(t, 0.060, 0.001)
                + 0.16 * resonances(t, [175.0 * p, 440.0 * p, 980.0 * p], 0.048, rng=rng)
            )
            add_at(out, chunk, delay * rng.uniform(0.92, 1.08), gain)
        # Granular falling rubble & concrete dust avalanche (far more realistic than modulated white noise)
        rubble = crackle_bed(t, rng, density=3600.0, low_hz=260.0, high_hz=5800.0,
                             decay_s=0.58, attack_s=0.08, amp_decay_s=0.0075)
        out += 0.34 * rubble
        out = outdoor_tail(out, rng, wet=0.44, decay=0.72, bright_hz=920.0, predelay=0.024)
        out += 0.28 * pink_noise(len(t), rng, 22.0, 180.0) * envelope(t, 0.82, 0.055)

    elif name == "tactical_ping":
        # Modern tactical command radar sonar ping: warm tactile onset + pure harmonic bell + lush micro-tail.
        click = filter_band(n_wave(t, 0.0008), 800.0, 4200.0) * 0.28
        # Warm fifth-interval radar resonance (D5 + A5 + faint warm octave D4 anchor)
        ping1 = (
            0.52 * np.sin(2.0 * np.pi * 587.33 * t) * envelope(t, 0.13, 0.002)
            + 0.30 * np.sin(2.0 * np.pi * 880.0 * t + 0.4) * envelope(t, 0.095, 0.0025)
            + 0.22 * np.sin(2.0 * np.pi * 293.66 * t) * envelope(t, 0.085, 0.002)
            + 0.10 * np.sin(2.0 * np.pi * 1760.0 * t) * envelope(t, 0.040, 0.0015)
        )
        # Subtle echo pulse at 95ms for unmistakable tactical beacon feel
        ping2 = (
            0.42 * np.sin(2.0 * np.pi * 880.0 * t) * envelope(t, 0.16, 0.003)
            + 0.24 * np.sin(2.0 * np.pi * 1174.66 * t + 0.7) * envelope(t, 0.12, 0.003)
            + 0.16 * np.sin(2.0 * np.pi * 440.0 * t) * envelope(t, 0.11, 0.002)
        )
        out = click + ping1
        add_at(out, ping2, 0.092, 0.65)
        out = outdoor_tail(out, rng, wet=0.22, decay=0.18, bright_hz=2600.0, predelay=0.012)

    else:
        raise ValueError(name)

    return finish(out, compress=(name != "tactical_ping"))


def finish(samples: np.ndarray, compress: bool = True) -> np.ndarray:
    # Remove DC, apply gentle bus glue & warm saturation, guarantee click-free boundaries.
    samples = samples - samples.mean()
    peak_raw = max(float(np.max(np.abs(samples))), 1e-8)
    samples = samples / peak_raw
    if compress:
        samples = bus_glue(samples, threshold=0.34, ratio=3.0, attack_ms=1.4, release_ms=42.0)
        samples = np.tanh(samples * 1.15)
    else:
        samples = np.tanh(samples * 0.92)
    samples = samples - samples.mean()
    attack_count = round(0.00025 * RATE)
    tail_count = round(0.018 * RATE)
    samples[:attack_count] *= np.sin(np.linspace(0, math.pi / 2, attack_count)) ** 2
    samples[-tail_count:] *= np.cos(np.linspace(0, math.pi / 2, tail_count)) ** 2
    samples *= PEAK / max(float(np.max(np.abs(samples))), 1e-8)
    pcm = np.rint(samples * 32767).astype("<i2")
    pcm[0] = 0
    pcm[-1] = 0
    return pcm


SPECS = [
    ("rifle_fire", 0.48, 14021, "Crisp ballistic rifle crack with cooling gas sweep and mechanical bolt"),
    ("autocannon_fire", 0.58, 14022, "Heavy 30mm automatic cannon report with tight metallic breech punch"),
    ("cannon_fire", 1.50, 14023, "Visceral 120mm tank cannon concussion with warm chest punch and valley thunder"),
    ("energy_fire", 0.30, 14024, "Helix magnetic-containment plasma discharge with warm ion pulse and harmonic sheen"),
    ("rail_fire", 0.44, 14025, "Electromagnetic induction crack, hypersonic Mach whip, and titanium rail ring"),
    ("missile_launch", 0.64, 14026, "Pneumatic tube pop, crackling solid-fuel igniter, and Doppler rocket roar"),
    ("impact_light", 0.17, 14027, "Sharp metallic armor deflection and tight kinetic thud"),
    ("impact_heavy", 1.60, 14028, "Layered HE warhead detonation, shockwave rumble, shrapnel, and valley boom"),
    ("infantry_fall", 0.38, 14029, "Grounded body and pack thud with subtle cloth and gear settle"),
    ("vehicle_destroy", 2.15, 14030, "Armored hull breach, secondary cook-off, tearing steel, and debris"),
    ("structure_destroy", 2.70, 14031, "Seismic structural collapse with cascading fractures and falling rubble"),
]


def write_wav(path: Path, samples: np.ndarray) -> None:
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(samples.tobytes())


def db(value: float) -> float:
    return round(20 * math.log10(max(value, 1e-12)), 3)


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    segments = [np.zeros(RATE, dtype="<i2")]
    entries = []
    reel_position = RATE
    variants = [(name, name, duration, seed, description) for name, duration, seed, description in SPECS]
    variants += [
        (f"{name}_{variant}", name, duration, seed + variant * 7919, description)
        for name, duration, seed, description in SPECS
        for variant in (2, 3)
    ]
    for name, kind, duration, seed, description in variants:
        pcm = synthesize(kind, duration, seed)
        path = DEST / (name + ".wav")
        write_wav(path, pcm)
        floating = pcm.astype(np.float64) / 32768
        peak = float(np.max(np.abs(floating)))
        rms = float(np.sqrt(np.mean(floating * floating)))
        assert 0.01 < rms and peak <= 10 ** (-3 / 20), (name, rms, peak)
        assert pcm[0] == 0 and pcm[-1] == 0, name
        assert np.isfinite(floating).all(), name
        entry = {
            "name": name,
            "path": str(path.relative_to(ROOT)),
            "description": description,
            "seed": seed,
            "duration_seconds": len(pcm) / RATE,
            "sample_rate": RATE,
            "channels": 1,
            "bits_per_sample": 16,
            "peak_dbfs": db(peak),
            "rms_dbfs": db(rms),
            "dc_offset": round(float(floating.mean()), 8),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "audition_start_seconds": reel_position / RATE,
            "audition_end_seconds": (reel_position + len(pcm)) / RATE,
        }
        entries.append(entry)
        segments += [pcm, np.zeros(round(RATE * 0.8), dtype="<i2")]
        reel_position += len(pcm) + round(RATE * 0.8)

    # Also regenerate tactical_ping.wav so the command ping matches the refined aesthetic.
    ping_pcm = synthesize("tactical_ping", 0.56, 14099)
    write_wav(DEST / "tactical_ping.wav", ping_pcm)

    reel_path = HERE / "combat-audition.wav"
    write_wav(reel_path, np.concatenate(segments))
    manifest = {
        "generator": "art/audio/build_combat_audio.py",
        "provenance": "Original mathematical synthesis; no source recordings or third-party samples.",
        "format": "48 kHz mono signed PCM16 little-endian WAV",
        "peak_ceiling_dbfs": -3.0,
        "audition_path": str(reel_path.relative_to(ROOT)),
        "audition_sha256": hashlib.sha256(reel_path.read_bytes()).hexdigest(),
        "audition_duration_seconds": reel_position / RATE,
        "assets": entries,
    }
    (HERE / "combat-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    for entry in entries:
        print(
            f"{entry['name']:20} {entry['duration_seconds']:5.2f}s  "
            f"peak {entry['peak_dbfs']:6.2f} dBFS  RMS {entry['rms_dbfs']:6.2f} dBFS"
        )
    print(f"Wrote {len(entries)} cues + tactical_ping.wav and {manifest['audition_duration_seconds']:.2f}s audition reel.")


if __name__ == "__main__":
    main()
