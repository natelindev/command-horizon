extends RefCounted


## Refined faction-distinctive diegetic construction completion cues,
## synthesized once per faction and mixed by CombatAudio.
static func _warm_chord(freq: float, lt: float, decay: float, attack: float = 0.006) -> float:
	if lt < 0.0:
		return 0.0
	var ph = TAU * (freq * lt + freq * 0.008 * 0.01 * (1.0 - exp(-lt / 0.01)))
	var env = minf(lt / attack, 1.0) * exp(-lt * decay)
	return (
		(
			sin(ph) * 0.62
			+ sin(ph * 2.0 + 0.5) * 0.22 * exp(-lt * decay * 0.55)
			+ sin(ph * 3.0 + 1.1) * 0.07 * exp(-lt * decay * 1.1)
		)
		* env
	)


static func make_stream(faction: String) -> AudioStreamWAV:
	var rate = 44100
	var duration = 1.05
	var count = int(rate * duration)
	var dry := PackedFloat32Array()
	dry.resize(count)
	var random = RandomNumberGenerator.new()
	random.seed = 4107
	var lp1 = 0.0
	var lp2 = 0.0
	var lp3 = 0.0
	for index in count:
		var t = float(index) / rate
		var white = random.randf_range(-1.0, 1.0)
		lp1 = lerpf(lp1, white, 0.22)
		lp2 = lerpf(lp2, lp1, 0.16)
		lp3 = lerpf(lp3, lp2, 0.12)
		var bp = lp1 - lp2
		var sample = 0.0
		if faction == "helix":
			# Luminous ascending crystalline phase-lock chord + silky harmonic air bloom.
			var shimmer = 1.0 + 0.045 * sin(TAU * 6.5 * t)
			var c1 = (
				_warm_chord(392.0, t, 4.4, 0.007) * 0.44 + _warm_chord(587.33, t, 4.8, 0.008) * 0.34
			)
			var c2 = (
				_warm_chord(587.33, t - 0.072, 3.4, 0.009) * 0.42
				+ _warm_chord(880.0, t - 0.072, 3.6, 0.010) * 0.32
				+ _warm_chord(1174.66, t - 0.072, 4.4, 0.012) * 0.14
			)
			var air_env = minf(maxf(t - 0.04, 0.0) / 0.04, 1.0) * exp(-maxf(t - 0.04, 0.0) * 4.2)
			sample = (c1 + c2) * 0.68 * shimmer + bp * air_env * 0.16
		elif faction == "frontier":
			# Rugged pneumatic air-wrench clank + solid welded latch + warm analog field blip.
			var clank_env = minf(t / 0.0018, 1.0) * exp(-t * 30.0)
			var clank = (
				sin(TAU * 175.0 * t) * 0.44
				+ sin(TAU * 465.0 * t) * 0.26
				+ sin(TAU * 1020.0 * t) * 0.14
				+ bp * 0.52
			)
			var t2 = maxf(t - 0.075, 0.0)
			var vent_env = (minf(t2 / 0.014, 1.0) * exp(-t2 * 7.2)) if t >= 0.075 else 0.0
			var pip = (
				_warm_chord(440.0, t - 0.105, 11.0, 0.004) * 0.44
				+ _warm_chord(659.25, t - 0.165, 8.5, 0.004) * 0.46
			)
			sample = clank * clank_env * 0.64 + bp * vent_env * 0.40 + pip * 0.62
		else:
			# Bastion: weighty hydraulic bolt lock-in + pressurized air-brake vent + muted brass fifth.
			var thud_env = minf(t / 0.002, 1.0) * exp(-t * 13.0)
			var sweep_f = 115.0 * exp(-t * 16.0) + 46.0
			var thud = (
				sin(TAU * sweep_f * t) * 0.56
				+ sin(TAU * 230.0 * t) * 0.20 * exp(-t * 24.0)
				+ lp3 * 0.50
			)
			var t2 = maxf(t - 0.055, 0.0)
			var hiss_env = (minf(t2 / 0.020, 1.0) * exp(-t2 * 5.0)) if t >= 0.055 else 0.0
			var hiss = (bp * 0.78 + lp2 * 0.22) * hiss_env * 0.42
			var brass = (
				_warm_chord(293.66, t - 0.055, 6.2, 0.008) * 0.42
				+ _warm_chord(440.0, t - 0.055, 6.6, 0.010) * 0.32
			)
			sample = thud * thud_env * 0.68 + hiss + brass * 0.62
		dry[index] = sample

	# Subtle outdoor yard reflection tail for grounded physical presence
	var tap1 = int(rate * 0.024)
	var tap2 = int(rate * 0.053)
	var pcm = PackedByteArray()
	pcm.resize(count * 2)
	for index in count:
		var t = float(index) / rate
		var s = dry[index]
		if index >= tap1:
			s += dry[index - tap1] * 0.16
		if index >= tap2:
			s += dry[index - tap2] * 0.09
		var fade_out = clampf((duration - t) / 0.035, 0.0, 1.0)
		s = tanh(s * 1.12) * fade_out
		pcm.encode_s16(index * 2, int(clampf(s, -0.95, 0.95) * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream
