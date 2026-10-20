extends "res://tests/headless/SaveRestoreEdges.gd"

# Rendered review captures for the art direction pass: biome lighting and grading, fog memory,
# minimap terrain, team colors, unit readability marks and HUD.
# Run without --headless: Godot --path . --script tests/rendered/ArtDirectionPreview.gd

const OUTPUT = "res://art/art-direction/"


func _run():
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _battle("res://source/match/maps/battlefields/DesertFrontierMap.tscn", "desert", true)
	await _battle("res://source/match/maps/AlpineRelay.tscn", "alpine", false)
	await _battle("res://source/match/maps/CoastalFoundry.tscn", "coastal", false)
	await _battle("res://source/match/maps/IndustrialCrossroads.tscn", "urban", false)
	await _battle("res://source/match/maps/BastionDesert.tscn", "bastion-desert", false)
	preferences.restore(original)
	for message in errors:
		push_error(message)
	print("Art direction preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _battle(map_path, label, detailed):
	await _skirmish("bastion", map_path, true)
	for player in get_nodes_in_group("players"):
		if player != game._get_human_player():
			player.set_process(false)
	var human = game._get_human_player()
	var camera = game.get_node("IsometricCamera3D")
	var tank = _units(human, "Tank")[0]
	var home = tank.global_position
	# Scout outward and return so explored-but-unobserved memory is visible.
	var scout = _units(human, "Tank")[-1]
	var scout_home = scout.global_position
	var center = Vector3(game.map.size.x / 2.0, 0, game.map.size.y / 2.0)
	for step in range(1, 9):
		scout.global_position = scout_home.lerp(center, step / 8.0)
		await _frames(4)
	scout.global_position = scout_home
	await _frames(30)
	camera.size_max = 190
	camera.set_size_safely(44)
	camera.set_position_safely(home.lerp(center, .35))
	await _frames(30)
	await _shot(label + "-hud")
	if not detailed:
		game.queue_free()
		await _frames(5)
		return
	camera.set_size_safely(18)
	camera.set_position_safely(home)
	for unit in _units(human, "Tank") + _units(human, "Worker"):
		unit.get_node("Selection").select()
	tank.hp = int(tank.hp_max * .55)
	_units(human, "Tank")[-1].hp = int(_units(human, "Tank")[-1].hp_max * .2)
	await _frames(20)
	await _shot(label + "-units")
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	await _frames(20)
	var minimap = game.find_child("Minimap", true, false)
	var area = Rect2i(root.get_final_transform() * minimap.get_global_rect())
	RenderingServer.force_draw(false)
	var image = root.get_texture().get_image().get_region(area)
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png(OUTPUT + label + "-minimap.png")
	game.queue_free()
	await _frames(5)


func _shot(label):
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUTPUT + label + ".png")
	print("Captured ", label)
