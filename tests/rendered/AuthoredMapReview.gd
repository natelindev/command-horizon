extends "res://tests/headless/SaveRestoreEdges.gd"

# Review captures of an authored battlefield at the normal RTS camera: a plan
# of the whole map, the first start, every attack-lane crossing, landmarks and
# the first start's natural expansion. Run without --headless:
#   Godot --path . --script tests/rendered/AuthoredMapReview.gd -- [MapId] [--fog]

const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	preferences.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var map_id = "RedrockDivideMap"
	var fog = false
	for argument in OS.get_cmdline_user_args():
		if argument == "--fog":
			fog = true
		elif not argument.begins_with("--"):
			map_id = argument
	var path = Registry.ROOT + map_id + ".tscn"
	var layout = Registry.layout(path)
	var output = "res://art/map-review/%s/" % map_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	await _skirmish("bastion", path, false)
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	if not fog:
		game.fog_of_war.reveal()
	await _frames(30)
	var camera = game.get_node("IsometricCamera3D")
	var shots = [["start", layout.bases[0].start, 30.0]]
	for index in layout.ai.lanes.size():
		shots.append(["crossing-%d" % index, layout.ai.lanes[index], 34.0])
	var seen = {}
	for landmark in layout.get("landmarks", []):
		if landmark.get("player", 0) != 0 or seen.has(landmark.asset):
			continue
		seen[landmark.asset] = true
		shots.append([landmark.asset.get_file().to_snake_case(), landmark.position, 22.0])
	for expansion in layout.expansions:
		if expansion.get("player", 0) == 0:
			shots.append(["expansion-" + expansion.name.to_snake_case(), expansion.site, 30.0])
	for shot in shots:
		camera.set_position_safely(game.map.ground_point(shot[1]))
		camera.set_size_safely(shot[2])
		await _frames(12)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + shot[0] + ".png")
	print("Review captures saved to ", ProjectSettings.globalize_path(output))
	preferences.restore(original)
	quit()
