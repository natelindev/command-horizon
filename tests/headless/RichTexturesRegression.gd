extends "res://tests/headless/SaveRestoreEdges.gd"

# Contracts for the rich texture pass: scanned ground layers on every ground
# shader and backdrop, ground-only deterministic decals that survive save/restore,
# and baked vertex weathering on every faction model.
const TerrainTextures = preload("res://source/match/TerrainTextures.gd")
const GroundDecals = preload("res://source/match/effects/GroundDecals.gd")
const MAPS = [
	"PinebreakValley",
	"GlacierNarrows",
	"PlainAndSimple",
	"BastionDesert",
	"DesertFrontier",
	"AlpineRelay",
	"SplitSignalMap",
	"CoastalFoundry",
	"IndustrialCrossroads",
	"SupplyLineMap",
	"AirCorridorMap",
]
const MODELS = [
	"res://assets/models/bastion/demo",
	"res://assets/models/bastion/structures-v2",
	"res://assets/models/helix/v1",
	"res://assets/models/frontier/v1",
]


func _run():
	root.get_node("SaveManager").autosaves_enabled = false
	_check_imports()
	_check_shaders()
	_check_weathering()
	for map_name in MAPS:
		await _skirmish("bastion", "res://source/match/maps/%s.tscn" % map_name)
		for player in get_nodes_in_group("players"):
			player.set_process(false)
		_check_ground(map_name)
		var placed = _decals(map_name)
		if map_name == "IndustrialCrossroads":
			_check_setting()
			await _check_restore(placed)
		game.queue_free()
		await _frames(5)
	for message in errors:
		push_error(message)
	print("Rich textures: %d failures" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _check_imports():
	for layer in TerrainTextures.TILES:
		for suffix in ["_color.jpg", "_normal.jpg", "_data.webp"]:
			var path = TerrainTextures.ROOT + layer + suffix
			_check(load(path) is Texture2D, "Missing terrain layer " + path)
			var config = ConfigFile.new()
			_check(config.load(path + ".import") == OK, "Missing import " + path)
			_check(config.get_value("params", "compress/mode") == 2, "Not VRAM compressed " + path)
			_check(config.get_value("params", "mipmaps/generate", false), "No mipmaps " + path)
			if suffix == "_normal.jpg":
				_check(config.get_value("params", "compress/normal_map") == 1, "Normal map " + path)
			if suffix == "_data.webp":
				_check(config.get_value("params", "compress/high_quality"), "Data packing " + path)


func _check_shaders():
	var shaders = TerrainTextures.SHADERS.keys()
	for shader_name in shaders:
		var shader = load(TerrainTextures.SHADER_ROOT + shader_name)
		var names = shader.get_shader_uniform_list().map(func(uniform): return uniform.name)
		for uniform in ["base_color", "path_data", "accent_normal", "terrain_detail"]:
			_check(uniform in names, "%s lacks terrain layer input %s" % [shader_name, uniform])


func _check_weathering():
	for directory in MODELS:
		for file in DirAccess.get_files_at(directory):
			if not file.ends_with(".glb"):
				continue
			var scene = load(directory + "/" + file).instantiate()
			var darkest = 1.0
			for mesh in scene.find_children("*", "MeshInstance3D", true, false):
				for surface in mesh.mesh.get_surface_count():
					var colors = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_COLOR]
					var label = "%s/%s surface %d" % [directory, file, surface]
					_check(colors is PackedColorArray and colors.size() > 0, label + " unweathered")
					if colors is PackedColorArray:
						for color in colors:
							darkest = min(darkest, color.r)
							_check(color.r >= .34 and color.r <= 1.0, label + " occlusion range")
			_check(darkest < .9, file + " baked no visible occlusion")
			scene.free()


func _ground_materials():
	var found = []
	for mesh in game.map.find_children("*", "MeshInstance3D", true, false):
		var materials = [mesh.material_override]
		if mesh.mesh != null:
			for surface in mesh.mesh.get_surface_count():
				materials.append(mesh.get_active_material(surface))
		for material in materials:
			if material is ShaderMaterial and material.shader != null:
				var file = material.shader.resource_path.get_file()
				if file == "battlefield.gdshader" or TerrainTextures.SHADERS.has(file):
					found.append(material)
	return found


func _check_ground(map_name):
	var materials = _ground_materials()
	_check(not materials.is_empty(), map_name + " has no layered ground")
	for material in materials:
		for slot in TerrainTextures.SLOTS:
			_check(
				material.get_shader_parameter(slot + "_color") is Texture2D,
				"%s ground %s layer unbound" % [map_name, slot]
			)
			_check(
				material.get_shader_parameter(slot + "_tile") in TerrainTextures.TILES.values(),
				"%s ground %s tile size unset" % [map_name, slot]
			)


func _decals(map_name):
	var terrain = game.map.get_node("Geometry/Terrain")
	_check(terrain.get_layer_mask_value(GroundDecals.GROUND_LAYER), map_name + " ground layer")
	var decals = game.map.get_node_or_null("GroundDecals")
	_check(decals != null, map_name + " has no ground decals")
	if decals == null:
		return []
	var placed = []
	for decal in decals.get_children():
		_check(decal.cull_mask == 1 << (GroundDecals.GROUND_LAYER - 1), "Decal leaks off ground")
		_check(decal.texture_albedo != null, "Decal without texture")
		var inside = Rect2(Vector2.ZERO, game.map.size).has_point(
			Vector2(decal.position.x, decal.position.z)
		)
		_check(inside, "%s decal outside the battlefield" % map_name)
		placed.append([decal.texture_albedo.resource_path, decal.transform])
	var expected = int(game.map.size.x * game.map.size.y / GroundDecals.FIELD_AREA)
	_check(placed.size() >= expected, "%s placed only %d decals" % [map_name, placed.size()])
	if not GroundDecals.roads(terrain).is_empty():
		_check(
			placed.any(func(entry): return "skid" in entry[0] or "oil" in entry[0]),
			map_name + " roads have no wear decals"
		)
	# Decals must never land on units or structures.
	for unit in get_nodes_in_group("units"):
		for mesh in unit.find_children("*", "VisualInstance3D", true, false):
			_check(
				not mesh.get_layer_mask_value(GroundDecals.GROUND_LAYER),
				"%s unit mesh on the ground decal layer" % map_name
			)
	return placed


func _check_setting():
	var options = root.get_node("Globals").options
	var decals = game.map.get_node("GroundDecals")
	# The headless renderer keeps no shader globals; TerrainLayersPreview checks the
	# rendered ground for this setting.
	options.graphics_ground_detail = false
	options.apply()
	_check(not decals.visible, "Ground detail off left decals visible")
	options.graphics_ground_detail = true
	options.apply()
	_check(decals.visible, "Ground detail on did not restore decals")


func _check_restore(placed):
	paused = true
	var snapshot = Snapshot.new()
	var data = snapshot.capture(game)
	_check(data != null, "Decal match capture failed")
	if data == null:
		return
	var restored = await Restore.new().restore(self, data)
	_check(restored.ok, "Decal match restore failed: " + restored.get("error", ""))
	if not restored.ok:
		return
	game = restored.game
	_check_ground("restored IndustrialCrossroads")
	var again = _decals("restored IndustrialCrossroads")
	_check(again == placed, "Ground decals changed across save/restore")
	paused = false
