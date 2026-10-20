extends "res://tests/headless/SaveRestoreEdges.gd"

# Run without --headless. Close captures of each faction's units and structures.
# `-weathering-off` controls rebuild the same meshes with white vertex colors,
# which is exactly how unweathered geometry renders; lighting and camera match.
# Optional arguments after `--` select factions (for example `-- helix`).
const OUTPUT = "res://art/weathering/"

var _originals = {}


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
		push_error("Weathering preview needs a renderer; omit --headless")
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
				"living_world": false,
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
	for faction in ["bastion", "helix", "frontier"]:
		if not OS.get_cmdline_user_args().is_empty() and faction not in OS.get_cmdline_user_args():
			continue
		paused = false
		await _skirmish(faction, "res://source/match/maps/PinebreakValley.tscn")
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		await _frames(20)
		paused = true
		var human = game._get_human_player()
		var tank = _units(human, "Tank")[0]
		var hq = _units(human, "CommandCenter")[0]
		var units = get_nodes_in_group("units").filter(func(unit): return unit.player == human)
		_check(_weathered(units), faction + " models carry no baked weathering")
		await _pair(faction + "-vehicles", tank.global_position, 6, units)
		await _pair(faction + "-base", hq.global_position + Vector3(2, 0, 1), 14, units)
		game.queue_free()
		await _frames(5)
		paused = false
	preferences.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print("Weathering rendered preview: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _meshes(units):
	var meshes = []
	for unit in units:
		meshes.append_array(unit.find_children("*", "MeshInstance3D", true, false))
	return meshes.filter(func(mesh): return mesh.mesh is ArrayMesh)


func _weathered(units):
	for mesh in _meshes(units):
		for surface in mesh.mesh.get_surface_count():
			var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
			if colors is PackedColorArray and colors.size() > 0:
				return true
	return false


func _strip(units):
	for mesh in _meshes(units):
		var plain = ArrayMesh.new()
		for surface in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_COLOR] is PackedColorArray:
				var white = PackedColorArray()
				white.resize(arrays[Mesh.ARRAY_COLOR].size())
				white.fill(Color.WHITE)
				arrays[Mesh.ARRAY_COLOR] = white
			plain.add_surface_from_arrays(mesh.mesh.surface_get_primitive_type(surface), arrays)
			plain.surface_set_material(surface, mesh.mesh.surface_get_material(surface))
		_originals[mesh] = mesh.mesh
		mesh.mesh = plain


func _restore():
	for mesh in _originals:
		mesh.mesh = _originals[mesh]
	_originals.clear()


func _pair(label, point, zoom, units):
	await _capture(label, point, zoom)
	_strip(units)
	await _capture(label + "-weathering-off", point, zoom)
	_restore()


func _capture(label, point, zoom):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(zoom)
	camera.set_position_safely(point)
	await _frames(12)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty rendered capture: " + label)
	if pixels != null:
		_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Failed to save " + label)
	print("Captured ", label)
