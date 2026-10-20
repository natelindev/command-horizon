extends "res://tests/headless/SaveRestoreEdges.gd"

# Run without --headless. Close captures of each faction's units and structures.
# `-weathering-off` controls rebuild the same meshes with white vertex colors,
# which is exactly how unweathered geometry renders; lighting and camera match.
# Optional arguments after `--` select factions (for example `-- helix`).
# `--air-only` skips the existing vehicle/base comparisons. All 11 new models
# receive individual close-up pairs; Frontier's existing Kestrel is unchanged.
const OUTPUT = "res://art/weathering/"
const AIR_MODELS = {
	"bastion":
	{
		"Fighter": "Fighter",
		"Bomber": "Bomber",
		"Helicopter": "Helicopter",
		"AntiAirVehicle": "AntiAirVehicle",
	},
	"helix":
	{
		"Fighter": "TalonInterceptor",
		"Bomber": "ShrikeBomber",
		"Helicopter": "WraithTiltrotor",
		"AntiAirVehicle": "HaloSkimmer",
	},
	"frontier":
	{
		"Fighter": "HornetFighter",
		"Bomber": "BuzzardBomber",
		"AntiAirVehicle": "RipsawTruck",
	},
}

var _originals = {}
var _captures = 0
var _air_models_checked = 0


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
	var arguments = Array(OS.get_cmdline_user_args())
	for argument in arguments:
		_check(argument in AIR_MODELS or argument == "--air-only", "Unknown argument: " + argument)
	if not errors.is_empty():
		for message in errors:
			push_error(message)
		quit(1)
		return
	var factions = arguments.filter(func(argument): return argument in AIR_MODELS)
	var air_only = "--air-only" in arguments
	var expected_captures = 0
	var expected_models = 0
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
	for faction in AIR_MODELS:
		if not factions.is_empty() and faction not in factions:
			continue
		expected_models += AIR_MODELS[faction].size()
		expected_captures += (AIR_MODELS[faction].size() + (0 if air_only else 2)) * 2
		paused = false
		await _skirmish(faction, "res://source/match/maps/battlefields/PinebreakValleyMap.tscn")
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
		if not air_only:
			await _pair(faction + "-vehicles", tank.global_position, 6, units)
			await _pair(faction + "-base", hq.global_position + Vector3(2, 0, 1), 14, units)
		await _air_pairs(faction, human, tank.global_position)
		game.queue_free()
		await _frames(5)
		paused = false
	preferences.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	_check(
		_air_models_checked == expected_models, "Some aircraft/mobile-AA models were not reviewed"
	)
	_check(_captures == expected_captures, "Some weathering comparisons were not captured")
	for message in errors:
		push_error(message)
	print(
		(
			"Weathering rendered preview: %d failures, %d new models, %d captures"
			% [errors.size(), _air_models_checked, _captures]
		)
	)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _air_pairs(faction, player, point):
	# Keep the normal map lighting and production faction materials, but freeze
	# the model so flight, rotors and avoidance cannot change the control image.
	for unit in get_nodes_in_group("units"):
		unit.hide()
	for layer in game.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var catalog = load("res://source/match/BastionCatalog.gd")
	for role in AIR_MODELS[faction]:
		var unit = load(catalog.scene_path(role)).instantiate()
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		game._setup_and_spawn_unit(unit, Transform3D(Basis(), point), player, false)
		await _frames(12)
		var geometry = unit.get_node("Geometry")
		var model_name = AIR_MODELS[faction][role]
		var directory = "air-v1" if faction == "bastion" else "v1"
		var expected_path = "res://assets/models/%s/%s/%s.glb" % [faction, directory, model_name]
		_check(
			geometry.get_child(0).scene_file_path == expected_path,
			"Wrong review model for %s/%s" % [faction, role]
		)
		_check(_weathered([geometry]), "%s/%s carries no baked weathering" % [faction, model_name])
		var bounds = _model_bounds(geometry)
		_check(bounds.size.length_squared() > 0, "Empty review model: " + model_name)
		# The bounding sphere fits either viewport axis, including rotor tips.
		var zoom = maxf(3.5, bounds.size.length() * 1.6)
		await _pair(
			"%s-air-%s" % [faction, model_name.to_snake_case()],
			bounds.get_center(),
			zoom,
			[geometry],
			bounds
		)
		_air_models_checked += 1
		unit.queue_free()
		await _frames(2)


func _model_bounds(geometry):
	var bounds = AABB()
	var first = true
	for mesh in _meshes([geometry]):
		var box = mesh.global_transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


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


func _pair(label, point, zoom, units, bounds = AABB()):
	await _capture(label, point, zoom, bounds)
	_strip(units)
	await _capture(label + "-weathering-off", point, zoom, bounds)
	_restore()


func _capture(label, point, zoom, bounds = AABB()):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.set_size_safely(zoom)
	camera.set_position_safely(point)
	await _frames(12)
	if bounds.size.length_squared() > 0:
		var frame = root.get_visible_rect().grow(-24)
		for corner in range(8):
			var vertex = bounds.get_endpoint(corner)
			_check(
				(
					not camera.is_position_behind(vertex)
					and frame.has_point(camera.unproject_position(vertex))
				),
				"Clipped review model: " + label
			)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty rendered capture: " + label)
	if pixels != null:
		_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Failed to save " + label)
		_captures += 1
	print("Captured ", label)
