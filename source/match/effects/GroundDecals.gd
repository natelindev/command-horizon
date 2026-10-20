extends Node3D

# Cosmetic ground decals: stains, skids and repairs along each map's roads, and
# tracks, scuffs and debris across open ground. Placement is seeded by the map
# scene, so every load (including restored saves) shows the same ground. Decals
# only project onto meshes on GROUND_LAYER, never onto units, structures or water.
const AtmosphereProfiles = preload("res://source/match/environment/AtmosphereProfiles.gd")
const GROUND_LAYER = 11
const ROOT = "res://assets/textures/decals/"
const ROAD_SPACING = 13.0
const FIELD_AREA = 340.0
# Biome tint applied to the neutral decal textures.
const TINTS = {
	"desert": Color(1.0, .88, .72),
	"alpine": Color(.82, .9, 1.0),
	"temperate": Color(.92, .93, .8),
	"urban": Color(1, 1, 1),
	"coastal": Color(.95, .97, .97),
}
const PAVED = ["urban", "coastal"]

var _rng = RandomNumberGenerator.new()
var _textures = {}
var _tint = Color.WHITE
var _bounds = Rect2()


# Applies the "Ground detail" setting: scanned layers via the shader global and
# this map's decals. Safe before the decals exist; they read the option on ready.
static func set_detail(map, enabled):
	RenderingServer.global_shader_parameter_set("ground_detail", 1.0 if enabled else 0.0)
	var decals = map.get_node_or_null("GroundDecals") if map != null else null
	if decals != null:
		decals.visible = enabled


func _ready():
	visible = get_node("/root/Globals").options.graphics_ground_detail
	var map = get_parent()
	var terrain = map.get_node_or_null("Geometry/Terrain")
	if terrain == null:
		return
	terrain.set_layer_mask_value(GROUND_LAYER, true)
	var biome = AtmosphereProfiles.biome(map)
	_tint = TINTS.get(biome, Color.WHITE)
	_rng.seed = hash(map.scene_file_path)
	var paved = biome in PAVED
	_bounds = Rect2(Vector2.ONE * 2.0, map.size - Vector2.ONE * 4.0)
	for segment in roads(terrain):
		_road(segment, paved)
	_field(map.size, paved)


static func roads(terrain):
	var material = terrain.material_override
	if material == null and terrain.mesh != null:
		material = terrain.mesh.surface_get_material(0)
	if not material is ShaderMaterial:
		return []
	var values = material.get_shader_parameter("roads")
	if values == null:
		return []
	var count = material.get_shader_parameter("road_count")
	var segments = []
	for index in min(values.size(), count if count is int else values.size()):
		var road: Vector4 = values[index]
		var a = Vector2(road.x, road.y)
		var b = Vector2(road.z, road.w)
		if a.distance_to(b) > 4.0:
			segments.append([a, b])
	return segments


func _road(segment, paved):
	var a: Vector2 = segment[0]
	var b: Vector2 = segment[1]
	var along = (b - a).normalized()
	var across = Vector2(-along.y, along.x)
	for index in int(a.distance_to(b) / ROAD_SPACING):
		var point = a.lerp(b, _rng.randf()) + across * _rng.randf_range(-2.2, 2.2)
		# Roads may continue into the exterior backdrop; decals stay on the battlefield.
		if not _bounds.has_point(point):
			continue
		var heading = atan2(along.x, along.y) + _rng.randf_range(-.12, .12)
		var roll = _rng.randf()
		if roll < .35:
			_place(
				["oil_stain_a", "oil_stain_b"][_rng.randi() % 2], point, _rng.randf_range(1.3, 2.4)
			)
		elif roll < .6:
			_place("skid_marks", point, 1.7, heading, _rng.randf_range(4.0, 6.5))
		elif paved and roll < .85:
			_place(["cracks_a", "cracks_b"][_rng.randi() % 2], point, _rng.randf_range(2.5, 4.5))
		elif paved:
			_place("repair_patch", point, _rng.randf_range(1.8, 3.0), heading, 3.2)
		else:
			_place("tire_tracks", point, 2.6, heading, _rng.randf_range(6.0, 9.0), .6)


func _field(size: Vector2, paved):
	for index in int(size.x * size.y / FIELD_AREA):
		var point = Vector2(_rng.randf_range(3, size.x - 3), _rng.randf_range(3, size.y - 3))
		var roll = _rng.randf()
		if roll < .32:
			_place("tire_tracks", point, 2.6, _rng.randf() * TAU, _rng.randf_range(6.0, 10.0), .65)
		elif roll < .58:
			_place("scuff", point, _rng.randf_range(3.0, 6.0), _rng.randf() * TAU, 0.0, .55)
		elif roll < .78:
			_place("debris", point, _rng.randf_range(1.6, 3.0))
		elif paved:
			_place(["cracks_a", "cracks_b"][_rng.randi() % 2], point, _rng.randf_range(3.0, 5.0))
		else:
			_place(
				["oil_stain_a", "oil_stain_b"][_rng.randi() % 2],
				point,
				_rng.randf_range(1.0, 1.8),
				0.0,
				0.0,
				.7
			)


func _place(texture, point: Vector2, width, heading = null, length = 0.0, strength = 1.0):
	if not _textures.has(texture):
		_textures[texture] = load(ROOT + texture + ".png")
	var decal = Decal.new()
	decal.texture_albedo = _textures[texture]
	decal.cull_mask = 1 << (GROUND_LAYER - 1)
	decal.size = Vector3(width, 1.0, length if length > 0.0 else width)
	decal.modulate = Color(_tint, strength)
	decal.upper_fade = .2
	decal.lower_fade = .2
	decal.position = Vector3(point.x, 0.0, point.y)
	decal.rotation.y = heading if heading != null else _rng.randf() * TAU
	add_child(decal)
