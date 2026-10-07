extends "res://tests/headless/HQCountdownRegression.gd"


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var response = load("res://tests/playtest/reference/GuardResponsePolicy.gd")
	var library = load("res://source/match/programs/ProgramLibrary.gd")
	for faction in ["bastion", "helix", "frontier"]:
		await _mirror(faction)
		var owner = game._get_human_player()
		var enemy = get_nodes_in_group("players").filter(func(side): return side != owner)[0]
		var walker = _spawn("CombatRobot", owner, Vector3(30, 0, 50))
		var air = _spawn("Helicopter", enemy, Vector3(34, 1.5, 54))
		var ground = _spawn("Tank", enemy, Vector3(34, 0, 48))
		for target in [air, ground]:
			target.process_mode = Node.PROCESS_MODE_DISABLED
			target.hp = 1000
		await _frames(5)
		game.battlefield.invalidate()
		_check(
			(
				game.battlefield.is_observed(owner, air)
				and game.battlefield.is_observed(owner, ground)
			),
			"Role fixture lacks observation"
		)
		walker.program.installed = true
		walker.program.configure(library.defaults("guard"), "Role response")
		walker.program.anchor = walker.position
		walker.program.safe_point = Vector3(27, 0, 48)
		_check(walker.program.run(), "Role guard failed to run")
		game.hud._toggle_pause()
		await _frames(3)
		game.hud.pause_after_load()
		response.update(walker, [air, ground], Vector3(30, 0, 48))
		var expected = ground.position if faction == "helix" else air.global_position_yless
		_check(walker.program.anchor == expected, "Walker stance/domain chose wrong threat")
		if faction == "helix":
			_check(walker.request_weapon_mode("interception"), "Interception switch refused")
			game.hud._toggle_pause()
			await _frames(125)
			game.hud.pause_after_load()
			response.update(walker, [air, ground], Vector3(30, 0, 48))
			_check(
				(
					walker.weapon_mode == "interception"
					and walker.program.anchor == air.global_position_yless
				),
				"Completed Interception stance did not choose aircraft"
			)
		var previous = walker.program.anchor
		response.update(walker, [air, ground], Vector3(20, 0, 48), true)
		_check(walker.program.anchor == previous, "Protected walker was reassigned")
		paused = false
		game.queue_free()
		await _frames(5)
	for error in errors:
		push_error(error)
	print("Guard response roles: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _spawn(role, player, point):
	var unit = load("res://source/match/units/%s.tscn" % role).instantiate()
	game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
	return unit
