extends "res://tests/headless/MechanicsRegression.gd"

var cases := 0


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var before = (
		FileAccess
		. get_file_as_string(
			"res://docs/playtests/2026-11-02/movement-dust-refresh/movement-dust-before.gd.txt"
		)
		. replace("func movement_dust(unit):", "func baseline_movement_dust(unit):")
	)
	var probe_script = GDScript.new()
	probe_script.source_code = (
		'extends "res://source/match/effects/CombatEffects.gd"\n'
		+ "var captured = []\nvar recording = true\nvar puff_count = 0\n"
		+ "func _ready():\n\t_ground_map = get_parent().map\n\tset_process(false)\n"
		+ "func _puff(kind, point, velocity, color, size):\n"
		+ "\tpuff_count += 1\n\tif recording:\n"
		+ "\t\tcaptured.append([kind, point, velocity, color, size])\n\n"
		+ before
	)
	_check(probe_script.reload() == OK, "Cannot compile before/after emission observer")
	for faction in ["bastion", "helix", "frontier"]:
		await _open(faction)
		var effects = probe_script.new()
		_game.add_child(effects)
		for role in ["Tank", "Worker", "Infantry"]:
			var unit = _spawn(role, _human, Vector3(40, 0, 40))
			for heading in [0.0, .7, 1.9, 3.1]:
				unit.rotation.y = heading
				for velocity in [Vector3.ZERO, Vector3(1, 0, 0), Vector3(2, 0, -2)]:
					unit.get_node("Movement").velocity = velocity
					for biome in ["desert", "temperate", "coastal", "alpine", "volcanic", "urban"]:
						effects._dust_biome = biome
						_compare(effects, unit)
			for state in ["hidden", "paused", "restoring"]:
				unit.visible = state != "hidden"
				paused = state == "paused"
				_game.restoring = state == "restoring"
				_compare(effects, unit)
				_check(effects.captured.is_empty(), "Rejected dust emitted for " + state)
				unit.show()
				paused = false
				_game.restoring = false
			unit.free()
		var measured = _spawn("Tank", _human, Vector3(40, 0, 40))
		measured.get_node("Movement").velocity = Vector3(2, 0, -2)
		effects._dust_biome = "temperate"
		effects.recording = false
		var native = ClassDB.instantiate("CopperfinPosePacker")
		var samples = {"before": [], "after": []}
		for index in 12:
			var names = ["before", "after"] if index % 2 == 0 else ["after", "before"]
			for name in names:
				var start = native.cpu_sample()
				for call_index in 500:
					if name == "before":
						effects.baseline_movement_dust(measured)
					else:
						effects.movement_dust(measured)
				var finish = native.cpu_sample()
				_check(start[0] == 1 and finish[0] == 1, "Caller CPU clock unavailable")
				samples[name].append(finish[2] - start[2])
		print(
			"DUST CPU faction=",
			faction,
			" calls_per_sample=500 caller_us=",
			JSON.stringify(samples)
		)
		measured.free()
		effects.free()
		_game.queue_free()
		await _frames(5)
	for message in _errors:
		push_error(message)
	print("Movement dust parity: ", cases, " cases; ", _errors.size(), " failures")
	await root.get_node("Globals").quit_game(0 if _errors.is_empty() else 1)


func _compare(effects, unit):
	effects.captured.clear()
	effects.baseline_movement_dust(unit)
	var expected = effects.captured.duplicate(true)
	effects.captured.clear()
	effects.movement_dust(unit)
	_check(effects.captured == expected, "Dust/clod output changed for " + unit.type)
	cases += 1
