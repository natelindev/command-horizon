extends "res://tests/headless/UnitAnimationRegression.gd"


func _run():
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.effects_volume = .75
	options.master_volume = .75
	for faction in ["bastion", "helix", "frontier"]:
		await _fixture(faction)
		var camera = _game.get_node("IsometricCamera3D")
		camera.set_physics_process(false)
		camera.set_size_safely(30)
		camera.set_position_safely(Vector3(30, 0, 12))
		var units := []
		var audio = _game.combat_audio
		audio.set_process(false)
		for index in 6:
			var unit = _spawn("Tank", 0, Vector3(25 + index * 2, 0, 12))
			unit.hp = unit.hp_max * .24
			unit.get_node("BastionVisuals")._update_damage(.21)
			units.append(unit)
		units[-1].add_to_group("selected_units")
		audio._refresh_damage_loops()
		var voices = _damage_voices(audio)
		_check(voices.size() == 4, "Damage loop cap or audible fixture failed for " + faction)
		_check(
			voices.any(func(v): return v.unit.get_ref() == units[-1]),
			"Selected unit missing damage voice priority"
		)
		for voice in voices:
			_check(
				voice.node.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
				"Damage loop is not seamless"
			)
		var dead = voices[0].unit.get_ref()
		dead.hp = 0
		audio._process(.01)
		_check(
			not _damage_voices(audio).any(func(v): return v.unit.get_ref() == dead),
			"Dead unit sustained machinery audio"
		)
		for unit in units:
			unit.hp = unit.hp_max
			unit.get_node("BastionVisuals")._update_damage(.21)
		audio._process(.01)
		_check(_damage_voices(audio).is_empty(), "Repaired vehicles sustained damage audio")
		_game.settings.visibility = _game.settings.Visibility.PER_PLAYER
		var distant = Vector3(75, 0, 75)
		_check(not audio.point_observed(distant), "Warning fixture is already observed")
		_check(audio.commander_warning(faction, distant), "Public off-camera warning was inaudible")
		_check(audio.commander_emp(distant), "Public EMP had no electronic pulse")
		_check(not audio.point_observed(distant), "Public audio revealed terrain")
		_check(
			not audio.point_impact(distant), "Public voice reuse leaked an ordinary hidden impact"
		)
		paused = true
		_check(not audio.commander_warning(faction, distant), "Paused public warning played")
		paused = false
		_check(audio._players.size() <= audio.MAX_PLAYERS, "Public cues exceeded shared voice pool")
		await _close()
	options.restore(original)
	for message in _errors:
		push_error(message)
	print("Vehicle damage audio regression: %d failures" % _errors.size())
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _damage_voices(audio):
	return audio._players.filter(
		func(entry):
			return entry.active and entry.kind in ["damage_diesel", "damage_plasma", "damage_steam"]
	)
