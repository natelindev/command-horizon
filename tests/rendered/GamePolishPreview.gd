extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/game-polish/"


func _run():
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for language in ["en", "zh_CN"]:
		preferences.restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"interface_scale": 1.5,
				"language": language,
				"day_cycle": false,
				"weather": 1
			}
		)
		await create_timer(2).timeout
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(1920, 1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		await _skirmish("bastion", "res://source/match/maps/ExpandedDesertFrontier.tscn", true)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		paused = true
		var human = game._get_human_player()
		var camera = game.get_node("IsometricCamera3D")
		var tank = _units(human, "Tank")[0]
		camera.set_position_safely(tank.global_position)
		camera.set_size_safely(26)
		game.hud.select_units([tank])
		await _frames(10)
		var point = tank.global_position + Vector3(5, 0, 3)
		game.hud.direct_orders.arm("move")
		_check(game.hud.direct_orders.commit(point, null, false), "Preview move rejected")
		await _frames(2)
		await _shot("command-move-" + language)
		var orders = load("res://source/match/orders/ManualOrders.gd")
		tank.manual_orders.submit(orders.point_order("move", point + Vector3(2, 0, 2)), true)
		await _frames(2)
		await _shot("command-queued-" + language)
		game.hud.command_feedback.markers.clear()
		tank.manual_orders.cancel()
		for index in orders.LIMIT:
			tank.manual_orders.submit(orders.point_order("move", point), true, false)
		tank.manual_orders.submit(orders.point_order("move", point), true)
		await _frames(2)
		await _shot("command-rejected-" + language)
		game.hud.command_feedback.markers.clear()
		game.hud.select_units([])
		camera.set_position_safely(_units(human, "CommandCenter")[0].global_position)
		camera.set_size_safely(23)
		await _frames(20)
		await _shot("base-" + language)
		await _close_preview()
		await _mission("first_orders", "FirstOrders")
		paused = true
		human = game._get_human_player()
		human.resource_a = 0
		await _frames(20)
		await _shot("first-orders-gather-" + language)
		human.resource_a = 100
		human.resource_b = 100
		await _frames(20)
		await _shot("first-orders-build-" + language)
		game.phase = 1
		game.hud._find_button.pressed.emit()
		await _frames(20)
		await _shot("first-orders-guard-" + language)
		game.phase = 2
		game.hud._find_button.pressed.emit()
		await _frames(20)
		await _shot("first-orders-capture-" + language)
		game.relay.captured_by = human
		game.relay.contested = true
		await _frames(20)
		await _shot("first-orders-contested-" + language)
		game._finish("Victory")
		await _frames(20)
		await _shot("first-orders-debrief-" + language)
		DirAccess.remove_absolute(game.progress_path)
		await _close_preview()
		await _mission("supply_line", "SupplyLine")
		paused = true
		game.convoy[0].unit.hp = game.convoy[0].unit.hp_max * .4
		game.hud._repair.pressed.emit()
		await _frames(20)
		await _shot("supply-repair-" + language)
		await _close_preview()
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Game polish preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _mission(mission, scene):
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.mission_id = mission
	settings.map_path = "res://source/match/maps/%sMap.tscn" % scene
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load("res://source/match/campaign/%s.tscn" % scene).instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	game.progress_path = "user://game-polish-preview-%d.json" % OS.get_process_id()
	root.add_child(game)
	current_scene = game
	game.get_node("IsometricCamera3D").set_physics_process(false)
	await _frames(40)
	game.campaign_story.skip_briefing()
	await _frames(4)


func _close_preview():
	paused = false
	game.queue_free()
	await _frames(5)


func _shot(label):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
