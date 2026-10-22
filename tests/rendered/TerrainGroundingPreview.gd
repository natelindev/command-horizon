extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/terrain-grounding/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Terrain grounding preview requires a renderer")
		quit(1)
		return
	Engine.max_fps = 60
	root.get_node("SaveManager").autosaves_enabled = false
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore({"screen": 1, "edge_scrolling": false, "day_cycle": false, "weather": 1})
	await create_timer(2).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/battlefields/AlpineRelayMap.tscn", false)
		var human = game._get_human_player()
		human.resource_a = 2000
		human.resource_b = 2000
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.fog_of_war.reveal()
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
		for point in [Vector2(40, 45), Vector2(43, 45), Vector2(46, 45)]:
			var unit = load("res://source/match/units/Infantry.tscn").instantiate()
			var position = Vector3(point.x, game.map.height_at(point), point.y)
			game._setup_and_spawn_unit(unit, Transform3D(Basis(), position), human)
		var camera = game.get_node("IsometricCamera3D")
		camera.set_size_safely(12)
		camera.set_position_safely(Vector3(43, 1.3, 47))
		await _frames(30)
		paused = true
		var handler = human.get_node("StructurePlacementHandler")
		handler._start_structure_placement(load("res://source/match/units/PowerPlant.tscn"))
		handler._active_blueprint_node.position = Vector3(
			43, game.map.height_at(Vector2(43, 49)), 49
		)
		handler._feedback_label.hide()
		for valid in [true, false]:
			handler._update_blueprint_color(valid)
			await _frames(4)
			await RenderingServer.frame_post_draw
			var label = faction + ("-valid" if valid else "-invalid")
			root.get_texture().get_image().save_png(OUTPUT + label + ".png")
			print("Captured ", label)
		handler._cancel_structure_placement()
		paused = false
		game.queue_free()
		await _frames(5)
	options.restore(original)
	quit()
