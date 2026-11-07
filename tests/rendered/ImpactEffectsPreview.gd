extends "res://tests/rendered/RayBeamPreview.gd"

var _output = "res://art/impact-polish/"


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("ImpactEffectsPreview requires a graphical renderer")
		quit(1)
		return
	if "--before" in OS.get_cmdline_user_args():
		_output += "before/"
	elif RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_output += "compatibility/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output))
	Engine.max_fps = 60
	var options = root.get_node("Globals").options
	var original = options.capture()
	options.restore(
		{
			"screen": 1,
			"edge_scrolling": false,
			"day_cycle": false,
			"weather": 1,
			"time_of_day": 0,
			"graphics_dof": false,
			"living_world": false,
			"battlefield_wear": false,
			"reduced_flashes": false
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	_setup_match()
	for side in get_nodes_in_group("players"):
		side.set_process(false)
	for unit in get_nodes_in_group("units"):
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.hide()
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	game.settings.visibility = game.settings.Visibility.FULL
	game.fog_of_war.reveal()
	var terrain = game.map.get_node("Geometry/Terrain")
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		# This gallery checks effects independently of the existing terrain shader,
		# which exceeds the Mac OpenGL sampler limit. Replace it before first draw.
		var floor_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color("787b7c")
		terrain.material_override = floor_material
	for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
		if mesh != terrain:
			mesh.hide()
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(14)
	camera.set_position_safely(ORIGIN + Vector3(0, .8, 1))
	_prepare_gallery()
	for item in _gallery_labels():
		var label = Label3D.new()
		label.text = item[0]
		label.font_size = 32
		label.pixel_size = .008
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		game.add_child(label)
		label.position = ORIGIN + Vector3(item[1], .1, item[2])
	await _frames(10)
	var baseline = await _impact_capture("baseline")
	_emit_gallery()
	for frame in 110:
		_gallery_frame(frame)
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60.0)
		var pixels = root.get_texture().get_image()
		_check(pixels.save_png(_output + "effects-%03d.png" % frame) == OK, "Capture failed")
		if frame == 8:
			_check(_changed_pixels(baseline, pixels) > 200, "Impact gallery is empty")
	options.reduced_flashes = true
	_emit_gallery()
	for frame in 18:
		await process_frame
		RenderingServer.force_draw(true, 1.0 / 60.0)
	await _impact_capture("reduced-flashes")
	_check(game.combat_effects._shockwaves.is_empty(), "Reduced flashes retained pressure rings")
	game.queue_free()
	await _frames(5)
	options.restore(original)
	OS.remove_logger(logger)
	errors.append_array(logger.messages)
	for message in errors:
		push_error(message)
	print("Impact effects preview: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _prepare_gallery():
	pass


func _gallery_labels():
	return [
		["HEAVY BLAST", -3.5, -1.0],
		["FRAGMENTATION", 3.5, -1.0],
		["ARMOR HIT", -3.5, 5.0],
		["AIRBURST", 3.5, 5.0]
	]


func _gallery_frame(_frame):
	pass


func _setup_match():
	var settings = load("res://source/data-model/MatchSettings.gd").new()
	settings.skirmish = true
	settings.map_path = "res://source/match/maps/IndustrialCrossroads.tscn"
	for index in 2:
		var side = load("res://source/data-model/PlayerSettings.gd").new()
		side.controller = index + 1
		side.faction = "bastion" if index == 0 else "helix"
		settings.players.append(side)
	game = load("res://source/match/Skirmish.tscn").instantiate()
	game.settings = settings
	game.map = load(settings.map_path).instantiate()
	root.add_child(game)
	current_scene = game


func _emit_gallery():
	var effects = game.combat_effects
	effects._explosion(ORIGIN + Vector3(-3.5, .2, -3), 1.65, true, true)
	effects.grenade_impact(ORIGIN + Vector3(3.5, .1, -3), 2.5, game._get_human_player())
	effects._armor_impact(ORIGIN + Vector3(-3.5, .7, 3), Vector3.LEFT, true, Color("ffd9a0"))
	effects.airburst(ORIGIN + Vector3(3.5, 2, 3), 1.2, Color("ffe2a8"))


func _impact_capture(label):
	await process_frame
	RenderingServer.force_draw()
	var pixels = root.get_texture().get_image()
	_check(pixels.save_png(_output + label + ".png") == OK, "Cannot save " + label)
	return pixels
