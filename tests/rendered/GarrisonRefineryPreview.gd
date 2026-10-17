extends "res://tests/headless/NeutralWorldRegression.gd"

const OUTPUT = "res://art/garrison-refinery/"


func _run():
	Engine.max_fps = 60
	Manual = load("res://source/match/orders/ManualOrders.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	path = "user://garrison-refinery-preview-%d.json" % OS.get_process_id()
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "day_cycle": false, "weather": 1, "language": "en"})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _create("ExpandedDesertFrontier")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var human = game._get_human_player()
	var enemy = get_nodes_in_group("players").filter(func(side): return side != human)[0]
	var building = game.get_node("NeutralWorld").buildings[0]
	for index in 4:
		var soldier = _spawn_infantry(
			human, building.global_position + Vector3(building.radius + 1 + index, 0, 0)
		)
		soldier.manual_orders.submit(Manual.target_order("garrison", building))
	await _frames(150)
	_check(building.occupants.size() == 4, "Preview shelter not occupied")
	building.select_occupants()
	var tank = _units(enemy, "Tank")[0]
	tank.position = building.global_position + Vector3(building.radius + 4, 0, 0)
	game.battlefield.invalidate()
	await _capture("garrison", building.global_position + Vector3(3, 0, 0), 22)
	for soldier in building.occupants.duplicate():
		soldier.manual_orders.submit(
			Manual.point_order("move", soldier.global_position_yless + Vector3(12, 0, 0))
		)
	await _frames(100)
	await _capture("unloaded", building.global_position + Vector3(3, 0, 0), 22)
	root.get_node("MatchSignals").deselect_all_units.emit()
	var refinery = game.map.points_of_interest.filter(func(site): return site.kind == "refinery")[0]
	refinery.set_physics_process(false)
	var capturer = _spawn_infantry(human, refinery.global_position + Vector3(3.8, 0, 0))
	await _frames(15)
	capturer.process_mode = Node.PROCESS_MODE_DISABLED
	game.battlefield.invalidate()
	refinery._physics_process(10)
	refinery._physics_process(9)
	_check(refinery.player == human, "Preview refinery not captured")
	await _capture("refinery-income", refinery.global_position, 24)
	refinery._physics_process(1)
	await _capture("refinery-payout", refinery.global_position, 24)
	await _close()
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Garrison/refinery preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _capture(label, point, size):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(size)
	camera.set_position_safely(point)
	await _frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
