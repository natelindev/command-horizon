extends "res://tests/headless/BattlePolishRegression.gd"


func _run():
	factions = load("res://source/match/FactionCatalog.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "language": "zh_CN", "edge_scrolling": false})
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	await _skirmish("helix", "res://source/match/maps/ExpandedDesertFrontier.tscn")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	await _production()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_position_safely(_units(game._get_human_player(), "VehicleFactory")[0].position)
	camera.set_size_safely(22)
	await _capture("balanced-production-zh")
	root.get_node("MatchSignals").deselect_all_units.emit()
	var player = game._get_human_player()
	var point = Vector3(67.5, 0, 85.5)
	var tank = _units(player, "Tank")[0]
	tank.position = point + Vector3(0, 0, -7)
	tank.set_physics_process(false)
	var infantry = _units(player, "Infantry")[0]
	infantry.position = point + Vector3(3, 0, -7)
	infantry.set_physics_process(false)
	var life = game.map.get_node("AmbientLife")
	life.set_physics_process(false)
	for actor in life.actors:
		actor.refresh_visibility(game)
	var fox = life.actors.filter(func(actor): return actor.entry.kind == "fox")[0]
	fox.position = point + Vector3(-3, 0, -7)
	var car = life.actors.filter(func(actor): return actor.entry.kind == "car")[0]
	car.position = point + Vector3(-6, 0, -7)
	camera.set_position_safely(point + Vector3(0, 0, -2))
	camera.set_size_safely(20)
	tank.get_node("Selection").select()
	infantry.get_node("Selection").select()
	await _capture("central-settlement-scale-zh")
	var handler = player.get_node("StructurePlacementHandler")
	handler._start_structure_placement(load("res://source/match/units/AntiGroundTurret.tscn"))
	handler._active_blueprint_node.position = point + Vector3(8, 0, 0)
	handler._placement_range.position = point + Vector3(8, .065, 0)
	await _capture("placement-range-zh")
	handler._cancel_structure_placement()
	# Reproduce a large mixed selection: only compact player-color outlines remain.
	var crowd = point + Vector3(0, 0, -10)
	for index in 16:
		var role = "Tank" if index % 4 == 0 else "Infantry"
		var unit = load(factions.Bastion.scene_path(role)).instantiate()
		game._setup_and_spawn_unit(
			unit,
			Transform3D(Basis(), crowd + Vector3((index % 4 - 2) * 2.5, 0, (index / 4 - 2) * 2)),
			player,
			false
		)
		unit.get_node("Selection").select()
	camera.set_position_safely(crowd)
	camera.set_size_safely(24)
	await _capture("group-selection-zh")
	game.queue_free()
	await _frames(5)
	options.restore(original)
	for message in errors:
		push_error(message)
	print("Battle polish rendered: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture(label):
	await _frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(
		"res://docs/playtests/2026-10-15/battle-polish/%s.png" % label
	)
