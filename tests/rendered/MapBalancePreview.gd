extends "res://tests/headless/Skirmish.gd"

# Rendered review captures of every skirmish map: a top-down plan of the whole
# battlefield and a gameplay-camera view between the first start and the center.
# Run without --headless:
#   Godot --path . --script tests/rendered/MapBalancePreview.gd -- [--output=<dir>] [Map ...]

const OUTPUT = "res://art/map-balance/"

var game
var output = OUTPUT


func _run():
	constants = root.get_node("Constants")
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	root.get_node("SaveManager").autosaves_enabled = false
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var only = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		elif not argument.begins_with("--"):
			only.append(argument)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for map_path in constants.Match.MAPS:
		var map_name = map_path.get_file().get_basename()
		if only.is_empty() or map_name in only:
			await _capture_map(map_path, map_name)
	preferences.restore(original)
	print("Map balance previews saved to ", output)
	quit()


func _capture_map(map_path, map_name):
	var settings = _settings("bastion", "helix", false)
	settings.map_path = map_path
	settings.visibility = 2
	settings.players[1].spawn_index_offset = constants.Match.MAPS[map_path].players / 2 - 1
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(map_path).instantiate()
	root.add_child(game)
	current_scene = game
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	await _frames(60)
	game.fog_of_war.reveal()
	var size = game.map.size
	var center = Vector3(size.x / 2.0, 0, size.y / 2.0)
	var plan = Camera3D.new()
	plan.projection = Camera3D.PROJECTION_ORTHOGONAL
	plan.keep_aspect = Camera3D.KEEP_HEIGHT
	plan.size = size.y * 1.04
	plan.near = 1
	plan.far = 400
	plan.position = center + Vector3(0, 150, 0)
	plan.rotation_degrees = Vector3(-90, 0, 0)
	game.add_child(plan)
	plan.make_current()
	var overlays = game.find_children("*", "CanvasLayer", true, false).filter(
		func(layer): return layer.visible
	)
	for layer in overlays:
		layer.visible = false
	await _shot(map_name + "-plan")
	for layer in overlays:
		layer.visible = true
	plan.queue_free()
	var camera = game.get_node("IsometricCamera3D")
	camera.make_current()
	var start = game.map.get_node("SpawnPoints").get_child(0).global_position
	camera.size_max = 190
	camera.set_size_safely(clampf(size.length() * .28, 34, 58))
	camera.set_position_safely(start.lerp(center, .45))
	await _shot(map_name + "-battle")
	game.queue_free()
	await _frames(5)


func _shot(label):
	await _frames(20)
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
