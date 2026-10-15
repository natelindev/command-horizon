extends "res://tests/headless/BattlePolishRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false})
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	await _skirmish("helix", "res://source/match/maps/ExpandedDesertFrontier.tscn")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(_units(game._get_human_player(), "CommandCenter")[0].position)
	camera.set_size_safely(28)
	await _measure_frames("base")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var center = Vector3(96, 0, 72)
	for player in get_nodes_in_group("players"):
		for index in 20:
			var role = ["Tank", "Infantry", "CombatRobot", "Helicopter"][index % 4]
			var unit = load(factions.Bastion.scene_path(role)).instantiate()
			var point = (
				center
				+ Vector3(
					(-6 if player == game._get_human_player() else 6) + (index % 4 - 2),
					0,
					(index / 4 - 2) * 2
				)
			)
			unit.hp_max = 100000
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
			unit.hp_max = 100000
			unit.hp = unit.hp_max
	camera.set_position_safely(center)
	camera.set_size_safely(34)
	await _measure_frames("midfield-combat")
	game.queue_free()
	await _frames(5)
	preferences.restore(original)
	quit()


func _measure_frames(label):
	await _frames(60)
	var times = []
	var last = Time.get_ticks_usec()
	var started = game.simulation_time
	for frame in 240:
		await process_frame
		var now = Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var mean = times.reduce(func(total, sample): return total + sample, 0.0) / times.size()
	print(
		"GAMEPLAY ",
		label,
		" units=",
		get_nodes_in_group("units").size(),
		" mean_ms=",
		snappedf(mean, .01),
		" p95_ms=",
		snappedf(times[int(times.size() * .95)], .01),
		" fps=",
		snappedf(1000.0 / mean, .1),
		" simulation_seconds=",
		game.simulation_time - started,
		" wall_seconds=",
		mean * times.size() / 1000.0,
		" viewport=",
		root.get_visible_rect().size
	)
