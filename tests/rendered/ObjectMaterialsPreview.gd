extends "res://tests/headless/SaveRestoreEdges.gd"

const OUTPUT = "res://art/object-materials/"
const Materials = preload("res://source/match/ObjectMaterials.gd")
const Vegetation = preload("res://source/match/maps/Vegetation.gd")
const ORIGIN = Vector3(51, 0, 51)
var _stage
var _captures = 0


class RenderErrorLog:
	extends Logger
	var messages = []
	var mutex = Mutex.new()

	func _log_error(_function, file, _line, code, rationale, _notify, _type, _backtraces):
		if _type == Logger.ERROR_TYPE_WARNING:
			return
		mutex.lock()
		messages.append(file + ": " + code + " " + rationale)
		mutex.unlock()


func _run():
	if DisplayServer.get_name() == "headless":
		push_error("ObjectMaterialsPreview requires a graphical renderer")
		quit(1)
		return
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
			"graphics_shadows": true,
			"graphics_ao": true,
			"graphics_msaa": 2
		}
	)
	root.get_node("SaveManager").autosaves_enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var logger = RenderErrorLog.new()
	OS.add_logger(logger)
	for faction in ["bastion", "helix", "frontier"]:
		await _skirmish(faction, "res://source/match/maps/IndustrialCrossroads.tscn")
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		game.settings.visibility = game.settings.Visibility.FULL
		game.fog_of_war.reveal()
		await _frames(20)
		paused = true
		var human = game._get_human_player()
		var tank = _units(human, "Tank")[0]
		var hq = _units(human, "CommandCenter")[0]
		await _capture(faction + "-battle", tank.global_position, 28)
		for layer in game.find_children("*", "CanvasLayer", true, false):
			layer.hide()
		await _capture(faction + "-base", hq.global_position, 16)
		await _capture(faction + "-vehicle", tank.global_position, 5)
		for unit in get_nodes_in_group("units"):
			unit.hide()
		# Keep the real ground, sun and atmosphere, but clear foreground scenery
		# from the controlled detail stage so roofs cannot hide the review models.
		var ground = game.map.get_node("Geometry/Terrain")
		for mesh in game.map.find_children("*", "GeometryInstance3D", true, false):
			if mesh != ground:
				mesh.hide()
		_stage = Node3D.new()
		game.add_child(_stage)
		var soldier = load("res://source/match/units/Infantry.tscn").instantiate()
		game._setup_and_spawn_unit(soldier, Transform3D(Basis(), ORIGIN), human, false)
		soldier.rotation.y = PI + .4
		soldier.process_mode = Node.PROCESS_MODE_DISABLED
		await _pair(faction + "-infantry", ORIGIN + Vector3(0, .5, 0), 1.8, soldier)
		soldier.hide()
		if faction == "bastion":
			await _scenery()
			await _biome_rocks()
			await _civilians()
			# Same real scene and fixed poses verify light/shadow controls.
			options.time_of_day = 2
			options.apply()
			await _capture("civilians-night", ORIGIN + Vector3(0, 1, 0), 16)
			options.time_of_day = 0
			options.apply()
		game.queue_free()
		await _frames(5)
		paused = false
	options.restore(original)
	OS.remove_logger(logger)
	for message in logger.messages:
		_check(false, message)
	for message in errors:
		push_error(message)
	print(
		"Object materials rendered preview: %d failures, %d captures" % [errors.size(), _captures]
	)
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _model(asset, point, height, weather_script = "", method = "weather"):
	var model = load("res://assets/models/environment/" + asset + ".glb").instantiate()
	Vegetation.fit_height(model, height)
	if not weather_script.is_empty():
		load("res://source/match/maps/" + weather_script + ".gd").call(method, model)
	Materials.apply(model)
	_stage.add_child(model)
	model.position = point
	return model


func _clear_stage():
	for child in _stage.get_children():
		child.free()


func _scenery():
	# Use the production merged-mesh path and its source materials, not a
	# separate gallery-only approximation of foliage.
	var batching = load("res://source/match/maps/terrain/MeshBatch.gd")
	for entry in [
		["temperate/OakTree", Vector3(-4, 0, -2), 6.0],
		["temperate/DouglasFir", Vector3(3, 0, -3), 7.0],
		["canyon/BoulderA", Vector3(-2, 0, 2), 1.2],
		["canyon/Sagebrush", Vector3(1, 0, 2), .8],
		["drylands/DuneGrass", Vector3(3, 0, 2), .7],
	]:
		var model = batching.merged_mesh(entry[0], entry[2])
		batching.add(
			_stage, model, [Transform3D(Basis(), ORIGIN + entry[1])], entry[0].get_file(), true
		)
	await _pair("vegetation", ORIGIN + Vector3(0, 1, 0), 14, _stage)
	await _pair("rocks-bushes-grass", ORIGIN + Vector3(1, .3, 2), 5, _stage)
	var options = root.get_node("Globals").options
	options.graphics_shadows = false
	options.graphics_ao = false
	options.apply()
	await _capture("vegetation-shadows-off", ORIGIN + Vector3(0, 1, 0), 14)
	options.graphics_shadows = true
	options.graphics_ao = true
	options.apply()
	_clear_stage()


func _civilians():
	_model("industrial/ServiceOffice", ORIGIN + Vector3(0, 0, -3), 6.0, "IndustrialMaterials")
	# Actual ambient setup includes the resident's per-instance coat override.
	var actor = load("res://source/match/ambient/AmbientActor.gd").new()
	actor.setup(
		{
			"kind": "resident",
			"id": "material-preview-resident",
			"start": 0.0,
			"length": 4.0,
			"path": PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 2)])
		},
		false
	)
	_stage.add_child(actor)
	actor.position = ORIGIN + Vector3(0, 0, 4)
	actor.show()
	actor._model.show()
	await _pair("civilian", actor.position + Vector3(0, .6, 0), 2.4, actor)
	await _capture("civilians-day", ORIGIN + Vector3(0, 1, 0), 16)


func _biome_rocks():
	for entry in [
		["desert/SandstoneShelfA", "DesertMaterials", "weather_stone"],
		["alpine/GlacialShelfA", "AlpineMaterials", "weather"],
		["coastal/CoastalHeadland", "CoastalMaterials", "weather"],
	]:
		var model = _model(entry[0], ORIGIN, 1.2, entry[1], entry[2])
		var bounds = Vegetation.bounds(model)
		await _capture(
			"rock-" + entry[0].get_file().to_snake_case(),
			bounds.get_center(),
			maxf(5.0, bounds.size.length() * 1.3)
		)
		_clear_stage()


func _materials(node, found):
	if node is MeshInstance3D and node.mesh != null:
		for index in node.mesh.get_surface_count():
			var material = node.get_active_material(index)
			if material is ShaderMaterial and material.has_meta("object_surface_family"):
				found[material] = true
	elif node is MultiMeshInstance3D:
		for index in node.multimesh.mesh.get_surface_count():
			var material = node.multimesh.mesh.surface_get_material(index)
			if material is ShaderMaterial and material.has_meta("object_surface_family"):
				found[material] = true
	for child in node.get_children():
		_materials(child, found)


func _pair(label, point, size, node):
	var materials = {}
	_materials(node, materials)
	_check(not materials.is_empty(), "Preview contains no object textures: " + label)
	var on = await _capture(label, point, size)
	for material in materials:
		material.set_shader_parameter("object_detail", 0.0)
	var off = await _capture(label + "-detail-off", point, size)
	_check(on.get_data() != off.get_data(), "Texture detail not visible: " + label)
	for material in materials:
		material.set_shader_parameter("object_detail", 1.0)


func _capture(label, point, size):
	var camera = game.get_node("IsometricCamera3D")
	camera.set_physics_process(false)
	camera.size_min = 1
	camera.set_size_safely(size)
	camera.set_position_safely(point)
	await _frames(12)
	await RenderingServer.frame_post_draw
	var pixels = root.get_texture().get_image()
	_check(pixels != null and not pixels.is_empty(), "Empty capture: " + label)
	_check(pixels.save_png(OUTPUT + label + ".png") == OK, "Cannot save " + label)
	_captures += 1
	print("Captured ", label)
	return pixels
