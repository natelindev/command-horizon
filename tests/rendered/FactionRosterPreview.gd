extends "res://tests/headless/FactionAsymmetryRegression.gd"

## Native rendered review of bespoke silhouette, combat identity, portraits and
## hidden firing-port occupants at the battle HUD's smallest supported window.
const OUTPUT = "res://art/faction-rosters/"


func _run():
	var logger = RuntimeErrorLog.new()
	OS.add_logger(logger)
	if DisplayServer.get_name() == "headless":
		push_error("Faction roster preview requires a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	factions = load("res://source/match/FactionCatalog.gd")
	technologies = load("res://source/match/research/TechnologyCatalog.gd")
	weapons = load("res://source/match/combat/WeaponCatalog.gd")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for language in ["en", "zh_CN"]:
		preferences.restore({"screen": 1, "interface_scale": 1.5, "edge_scrolling": false, "day_cycle": false, "weather": 1, "health_bars": 1, "language": language})
		await create_timer(1.0).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		for faction in factions.IDS:
			await _skirmish(faction, "res://source/match/maps/PlainAndSimple.tscn")
			human = game._get_human_player()
			human.resource_a = 10000
			human.resource_b = 10000
			for side in get_nodes_in_group("players"):
				side.set_process(false)
			for unit in get_nodes_in_group("units"):
				unit.process_mode = Node.PROCESS_MODE_DISABLED
			game.repair_service.set_physics_process(false)
			enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
			human.coordination_unlocked = true
			var signatures = []
			var roles = ["CombatRobot", "AdvancedTank", "AntiAirVehicle"]
			for index in roles.size():
				signatures.append(_dedicated(roles[index], Vector3(34 + index * 5, 0, 30)))
			await _frames(3)
			for index in signatures.size():
				signatures[index].global_position = Vector3(34 + index * 5, 0, 30)
			if faction == "bastion":
				signatures[1]._physics_process(2.0)
			elif faction == "frontier":
				for index in 4:
					var soldier = _dedicated("RocketInfantry" if index == 0 else "Infantry", signatures[1].global_position)
					await _frames(1)
					soldier.global_position = signatures[1].global_position
					signatures[1].garrison_mount.enter(soldier)
					_check(not soldier.visible, "Roster capture exposes garrisoned infantry")
			else:
				signatures[1].shields *= 0.6
				signatures[1].shields_changed.emit()
			game.settings.visibility = game.settings.Visibility.FULL
			var visibility = game.get_node("Handlers/UnitVisibilityHandler")
			for unit in get_nodes_in_group("units"):
				visibility._recalculate_unit_visibility(unit)
			game.fog_of_war._physics_process(0.0)
			var camera = game.get_node("IsometricCamera3D")
			camera.set_size_safely(13.0)
			camera.set_position_safely(Vector3(39, 0, 30))
			root.get_node("MatchSignals").deselect_all_units.emit()
			signatures[1].get_node("Selection").select()
			await _frames(20)
			root.mode = Window.MODE_WINDOWED
			root.size = Vector2i(1280, 720)
			await _frames(10)
			await RenderingServer.frame_post_draw
			var capture = root.get_texture().get_image()
			_check(capture.get_size() == Vector2i(1280, 720), "Roster review has incorrect viewport dimensions")
			capture.save_png(OUTPUT + faction + "-720p-" + language + ".png")
			game.queue_free()
			await _frames(5)
	preferences.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Faction roster rendered review: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)
