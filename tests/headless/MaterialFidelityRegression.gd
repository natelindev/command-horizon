extends "res://tests/headless/SaveRestoreEdges.gd"

const Surfaces = preload("res://source/match/SurfaceTextures.gd")
const Objects = preload("res://source/match/ObjectMaterials.gd")
const Terrain = preload("res://source/match/maps/terrain/TerrainModel.gd")
var dressing


func _run():
	dressing = load("res://source/match/maps/terrain/TerrainDressing.gd")
	root.get_node("SaveManager").autosaves_enabled = false
	_maps()
	for path in [
		"bastion/demo/Tank",
		"bastion/structures-v2/CommandCenter",
		"helix/v1/NeedleSkimmer",
		"helix/v1/NexusHQ",
		"frontier/v1/Outrider",
		"frontier/v1/ConvoyHQ",
		"bastion/air-v1/Fighter",
		"helix/v1/TalonInterceptor",
		"frontier/v1/HornetFighter"
	]:
		_trim(path)
	for path in [
		"temperate/OakTree", "temperate/DouglasFir", "temperate/BirchCluster", "desert/DryScrub"
	]:
		_foliage(path)
	_bridges()
	await _skirmish("bastion", "res://source/match/maps/battlefields/PinebreakValleyMap.tscn")
	for player in get_nodes_in_group("players"):
		player.set_process(false)
	var batches = {}
	var clear = dressing._clearances(game.map, game.map.layout)
	dressing._grass(game.map, batches, clear)
	var repeated = {}
	dressing._grass(game.map, repeated, clear)
	_check(batches == repeated, "Grass changed between identical map loads")
	_check(not batches.is_empty(), "Temperate forest and road verges have no grass")
	for batch in batches.values():
		_check(batch.transforms.size() <= 1800, "Grass exceeded instance budget")
		for placement in batch.transforms:
			var point = Vector2(placement.origin.x, placement.origin.z)
			_check(dressing._open(point, clear), "Grass obscures a road/base/resource lane")
			_check(
				not (
					game.map.terrain.flag_at(point)
					& (Terrain.WATER | Terrain.SOLID | Terrain.RAMP | Terrain.FORD | Terrain.BRIDGE)
				),
				"Grass on water or a ramp"
			)
			_check(
				abs(placement.origin.y - game.map.ground_point(point).y) < .001, "Floating grass"
			)
	var grass = game.map.get_node_or_null("Dressing/MeadowGrass")
	_check(
		grass is MultiMeshInstance3D and grass.get_child_count() == 0,
		"Grass is not a cosmetic batch"
	)
	for unit in _units(game._get_human_player(), "CommandCenter"):
		_check(
			unit.get_node_or_null("BaseApron") != null, "Structure lost its terrain contact skirt"
		)
	game.queue_free()
	await _frames(3)
	for message in errors:
		push_error(message)
	print("Material fidelity: %d failures" % errors.size())
	await root.get_node("Globals").quit_game(0 if errors.is_empty() else 1)


func _maps():
	for pair in [["Unrelated metal", false], ["Bastion_Steel", true]]:
		var original = StandardMaterial3D.new()
		original.resource_name = pair[0]
		var material = Objects.textured(original)
		_check(
			material.get_shader_parameter("trim_enabled") == pair[1],
			"Trim atlas claimed an unrelated UV2 layout"
		)
	for texture in [
		Surfaces.MICRO_NORMAL,
		Surfaces.MICRO_ORM,
		Surfaces.TRIM_COLOR,
		Surfaces.TRIM_NORMAL,
		Surfaces.TRIM_ORM
	]:
		var config = ConfigFile.new()
		_check(config.load(texture.resource_path + ".import") == OK, "Missing material map import")
		_check(config.get_value("params", "mipmaps/generate", false), "Material map has no mipmaps")
		_check(
			config.get_value("params", "compress/mode") == 2, "Material map is not VRAM-compressed"
		)
		if "normal" in texture.resource_path:
			_check(
				config.get_value("params", "compress/normal_map") == 1,
				"Normal map imported as color"
			)
		_check(
			texture.get_width() == (2048 if "trim" in texture.resource_path else 512),
			"Wrong material detail resolution"
		)
	for kind in ["leaves", "needles"]:
		var pixels = Image.load_from_file(
			ProjectSettings.globalize_path(
				"res://assets/textures/objects/generated/%s_cutout.png" % kind
			)
		)
		_check(pixels != null, "Missing foliage cutout")
		if pixels == null:
			continue
		var opaque = 0
		var clear = 0
		for x in range(0, pixels.get_width(), 7):
			for y in range(0, pixels.get_height(), 7):
				var alpha = pixels.get_pixel(x, y).a
				opaque += int(alpha > .5)
				clear += int(alpha < .1)
		_check(opaque > 100 and clear > 100, "Foliage mask lacks leaves or gaps")


func _trim(path):
	var full_path = "res://assets/models/%s.glb" % path
	_check(ResourceLoader.exists(full_path), "Missing trim fixture " + path)
	if not ResourceLoader.exists(full_path):
		return
	var model = load(full_path).instantiate()
	var trimmed = 0
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(surface)
			var uv = arrays[Mesh.ARRAY_TEX_UV2]
			if not uv is PackedVector2Array:
				continue
			var original = mesh.mesh.surface_get_material(surface)
			for point in uv:
				_check(
					(
						point.x >= -0.0001
						and point.x <= 1.0001
						and point.y >= -0.0001
						and point.y <= 1.0001
					),
					"Trim UV outside atlas: " + path
				)
				if point.x > .0001 and point.y > .0001:
					trimmed += 1
					_check(
						not original.resource_name.begins_with("TeamColor"),
						"Trim overwrote ownership markings"
					)
	_check(trimmed > 0, "No trim UVs exported: " + path)
	model.free()


func _foliage(path):
	var model = load("res://assets/models/environment/%s.glb" % path).instantiate()
	Objects.apply(model)
	var cards = 0
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if material is ShaderMaterial and material.shader == Objects.FOLIAGE_CARDS:
				cards += 1
				_check(
					material.get_shader_parameter("leaf_texture") is Texture2D,
					"Unbound cutout: " + path
				)
				var uv = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV]
				_check(uv is PackedVector2Array and uv.size() > 0, "Leaf cards lost UVs: " + path)
	_check(cards > 0, "Solid foliage was not replaced: " + path)
	model.free()


func _bridges():
	for bridge in ["temperate/LogBridge", "temperate/StoneBridge", "works/CanalBridge"]:
		var model = load("res://assets/models/environment/%s.glb" % bridge).instantiate()
		var deck_top = -INF
		for child in model.find_children("*", "MeshInstance3D", true, false):
			if "deck" in child.name.to_lower() or "lane" in child.name.to_lower():
				var aabb = child.mesh.get_aabb()
				var child_top = child.position.y + aabb.position.y + aabb.size.y
				deck_top = maxf(deck_top, child_top)
		_check(
			absf(deck_top) <= 0.05,
			"Bridge deck top not aligned to origin (height %.2f m): %s" % [deck_top, bridge]
		)
		model.free()
