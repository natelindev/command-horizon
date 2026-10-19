extends "res://tests/headless/SaveRestoreEdges.gd"

# Run without --headless. Detail-off controls retain the same average colors,
# lighting, camera and geometry; only the image variation is removed.
const OUTPUT = "res://art/texture-materials/"

var _bindings = []
var _armor_materials = []
var _flat_maps = {}


class RenderErrorLog:
	extends Logger

	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("Surface texture preview needs a renderer; omit --headless")
		quit(1)
		return
	Engine.max_fps = 60
	var preferences = root.get_node("Globals").options
	var original = preferences.capture()
	(
		preferences
		. restore(
			{
				"screen": 1,
				"edge_scrolling": false,
				"day_cycle": false,
				"weather": 1,
				"living_world": true,
				"time_of_day": 0,
				"interface_scale": 1.0,
				"graphics_dof": false,
			}
		)
	)
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await create_timer(1).timeout
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1920, 1200)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	_make_flat_maps()
	for faction in ["bastion", "helix", "frontier"]:
		if not OS.get_cmdline_user_args().is_empty() and faction not in OS.get_cmdline_user_args():
			continue
		paused = false
		await _skirmish(faction, "res://source/match/maps/IndustrialCrossroads.tscn")
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		# Let neutral buildings and actors refresh their own visibility before pause.
		await _frames(20)
		var buildings = get_nodes_in_group("neutral_buildings")
		_check(not buildings.is_empty(), "Industrial preview has no neutral buildings")
		for building in buildings:
			_check(building._model.is_visible_in_tree(), "Industrial building stayed hidden")
		paused = true
		var human = game._get_human_player()
		var tank = _units(human, "Tank")[0]
		var hq = _units(human, "CommandCenter")[0]
		_collect_bindings()
		await _capture(faction + "-battle", tank.global_position, 30)
		await _pair(faction + "-armor", tank.global_position, 9)
		await _capture(faction + "-base", hq.global_position + Vector3(2, 0, 1), 25)
		if faction == "bastion":
			await _pair("industrial-street", Vector3(61, 0, 43), 40)
			await _pair("industrial-detail", Vector3(59, 0, 44), 17)
			preferences.weather = 3
			preferences.apply()
			await _capture("industrial-rain", Vector3(61, 0, 43), 40)
			preferences.weather = 1
			preferences.apply()
		var site = load("res://source/match/units/PowerPlant.tscn").instantiate()
		game._setup_and_spawn_unit(site, Transform3D(Basis(), Vector3(64, 0, 52)), human, true)
		site.construct(.65)
		await _capture(faction + "-construction", site.global_position, 14)
		site.construct(1.0)
		await _frames(3)
		await _capture(faction + "-completed", site.global_position, 14)
		_bindings.clear()
		_armor_materials.clear()
		game.queue_free()
		await _frames(5)
		paused = false
	preferences.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print("Surface texture rendered preview: %d failures" % errors.size())
	print("Renderer: ", RenderingServer.get_current_rendering_method())
	quit(0 if errors.is_empty() else 1)


func _make_flat_maps():
	for pair in [
		["concrete_color", Color(.429, .402, .351)],
		["concrete_normal", Color(.5, .5, 1)],
		["concrete_roughness", Color(.754, .754, .754)],
		["asphalt_color", Color(.321, .264, .221)],
		["asphalt_normal", Color(.5, .5, 1)],
		["asphalt_roughness", Color(.79, .79, .79)],
	]:
		var pixels = Image.create(4, 4, false, Image.FORMAT_RGB8)
		pixels.fill(pair[1])
		pixels.generate_mipmaps()
		_flat_maps[pair[0]] = ImageTexture.create_from_image(pixels)


func _collect_bindings():
	var seen = {}
	for mesh in game.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if not material is ShaderMaterial or seen.has(material):
				continue
			seen[material] = true
			if material.get_shader_parameter("armor_panels") == true:
				_armor_materials.append(material)
			for parameter in _flat_maps:
				var texture = material.get_shader_parameter(parameter)
				if texture is Texture2D:
					_bindings.append([material, parameter, texture])


func _set_detail(enabled):
	for material in _armor_materials:
		material.set_shader_parameter("armor_panels", enabled)
	for binding in _bindings:
		binding[0].set_shader_parameter(
			binding[1], binding[2] if enabled else _flat_maps[binding[1]]
		)


func _pair(label, point, zoom):
	await _capture(label, point, zoom)
	_set_detail(false)
	await _capture(label + "-detail-off", point, zoom)
	_set_detail(true)


func _capture(label, point, zoom):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_max = 150
	camera.set_size_safely(zoom)
	camera.set_position_safely(point)
	await _frames(12)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty rendered capture: " + label)
	if pixels != null:
		_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Failed to save " + label)
	print("Captured ", label)
