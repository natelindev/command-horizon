extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/match-changes/"


func _run():
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "interface_scale": 1.0, "edge_scrolling": false})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var menu = load("res://source/main-menu/Play.tscn").instantiate()
	menu.preferences_path = "user://preview-match-changes.cfg"
	root.add_child(menu)
	menu._map_list.select(9)
	menu._on_map_list_item_selected(9)
	menu._game_mode.select(1)
	menu._apply_teams(1)
	menu._select_start(0, 3)
	await _frames(12)
	await _capture("four-player-setup")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	await _frames(5)
	await _frames(12)
	await _capture("four-player-slots-720p")
	menu.queue_free()
	await _frames(3)
	if "--setup-only" in OS.get_cmdline_user_args():
		options.restore(original)
		quit(0)
		return
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/IndustrialCrossroads.tscn")
		for side in get_nodes_in_group("players"):
			side.set_process(false)
		for unit in get_nodes_in_group("units"):
			unit.process_mode = Node.PROCESS_MODE_DISABLED
		var human = game._get_human_player()
		var depot = _units(human, "RepairDepot")[0]
		var tank = _units(human, "Tank")[0]
		tank.process_mode = Node.PROCESS_MODE_INHERIT
		tank.hp = tank.hp_max * 0.25
		tank.global_position = depot.global_position + Vector3(0, 0, 5)
		tank.issue_manual_order(
			load("res://source/match/units/actions/RecoveringAtService.gd").new(depot, true)
		)
		var camera = game.get_node("IsometricCamera3D")
		camera.set_size_safely(12)
		camera.set_position_safely(depot.global_position)
		tank.get_node("Selection").select()
		await _frames(250)
		await _capture(faction + "-repair-platform")
		game.queue_free()
		await _frames(5)
	await _skirmish("bastion", "res://source/match/maps/IndustrialCrossroads.tscn")
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
	var site = game.map.points_of_interest[0]
	var soldier = _units(game._get_human_player(), "Infantry")[0]
	soldier.process_mode = Node.PROCESS_MODE_INHERIT
	soldier.position = site.position + Vector3(site.radius + 0.8, 0, 0)
	soldier.issue_manual_order(load("res://source/match/units/actions/Garrisoning.gd").new(site))
	var camera = game.get_node("IsometricCamera3D")
	camera.set_size_safely(18)
	camera.set_position_safely(site.position)
	await _frames(360)
	await _capture("building-capture-progress")
	game.queue_free()
	await _frames(5)
	options.restore(original)
	quit(0)


func _capture(name):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")
