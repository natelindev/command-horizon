extends RefCounted


## Short diegetic cues, synthesized once per faction and mixed by CombatAudio.
static func make_stream(faction: String) -> AudioStreamWAV:
	var rate = 22050
	var duration = .8
	var pcm = PackedByteArray()
	pcm.resize(int(rate * duration) * 2)
	var random = RandomNumberGenerator.new()
	random.seed = 4107
	var filtered = 0.0
	for index in pcm.size() / 2:
		var time = float(index) / rate
		var envelope = minf(time / .015, 1.0) * pow(1.0 - time / duration, 2.0)
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), .35)
		var sample = filtered * .65
		if faction == "helix":
			sample = (
				(sin(TAU * 660 * time) + sin(TAU * 990 * time) * .35 + sin(TAU * 1320 * time) * .2)
				* .3
			)
		elif faction == "frontier":
			sample = (sin(TAU * 185 * time) + sin(TAU * 277.5 * time) * .45) * .28 + filtered * .15
		pcm.encode_s16(index * 2, int(clampf(sample * envelope, -.95, .95) * 32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream
