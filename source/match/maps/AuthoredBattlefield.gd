extends "res://source/match/Map.gd"

# Builds an authored, elevated battlefield from its definition (see
# BattlefieldRegistry): gameplay terrain, rendered ground, water, solid
# formations, forests, resource fields and start markers. Gameplay queries
# (height, tier, navigation source) answer from the same TerrainModel.

const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const TerrainMesh = preload("res://source/match/maps/terrain/TerrainMesh.gd")
const MeshBatch = preload("res://source/match/maps/terrain/MeshBatch.gd")
const Palettes = preload("res://source/match/maps/terrain/BiomePalettes.gd")
const Vegetation = preload("res://source/match/maps/Vegetation.gd")
const RESOURCE_A = preload("res://source/match/units/non-player/ResourceA.tscn")
const RESOURCE_B = preload("res://source/match/units/non-player/ResourceB.tscn")
const GROUND_SHADER = preload("res://source/shaders/3d/authored_terrain.gdshader")
const WATER_SHADER = preload("res://source/shaders/3d/battlefield_water.gdshader")
# Materials and electronics stock per deposit for each kind of field.
const STOCKS = {"home": [400, 720], "expansion": [600, 1200], "rich": [900, 1800]}
# Five material piles then two electronics nodes on an arc around the site
# where a headquarters stands (or can be built).
const PILE_SPACING = 2.6
const MATERIAL_PILES = 5
const ELECTRONICS_NODES = 2
const WATER_SURFACE_DROP = 0.3
const FORD_SURFACE_DROP = 0.08

var layout = {}
var terrain = null
var points_of_interest = []


func _enter_tree():
	if terrain == null and not Engine.is_editor_hint():
		_build_ground()
	super()


func _ready():
	if Engine.is_editor_hint():
		return
	_place_fields()
	for water in layout.water:
		_place_water(water)
	for blocker in layout.blockers:
		_place_blocker(blocker)
	_place_forests()


func height_at(point: Vector2) -> float:
	return terrain.height_at(point)


func tier_at(point: Vector2) -> int:
	return terrain.tier_at(point)


func max_height() -> float:
	return terrain.max_height


func is_elevated() -> bool:
	return true


func navigation_source_faces() -> PackedVector3Array:
	return terrain.navigation_faces()


func flight_height_at(point, baseline):
	# Aircraft follow a smoothed envelope of the ground beneath and ahead.
	var flat = Vector2(point.x, point.z)
	var lift = 0.0
	for offset in [
		Vector2.ZERO,
		Vector2(5, 0),
		Vector2(-5, 0),
		Vector2(0, 5),
		Vector2(0, -5),
		Vector2(9, 0),
		Vector2(-9, 0),
		Vector2(0, 9),
		Vector2(0, -9)
	]:
		lift = maxf(lift, terrain.height_at(flat + offset) - offset.length() * 0.2)
	return maxf(super(point, baseline), baseline + lift)


# Mouse events reach the terrain body through this 1 m height field; order
# points themselves come from the camera's exact terrain ray march.
func click_collision() -> Array:
	var shape = HeightMapShape3D.new()
	var step = int(round(1.0 / TerrainModel.RESOLUTION))
	shape.map_width = int(size.x) + 1
	shape.map_depth = int(size.y) + 1
	var data = PackedFloat32Array()
	data.resize(shape.map_width * shape.map_depth)
	for z in shape.map_depth:
		for x in shape.map_width:
			data[z * shape.map_width + x] = terrain.heights[
				z * step * (terrain.columns + 1) + x * step
			]
	shape.map_data = data
	return [shape, Transform3D(Basis(), Vector3(size.x / 2.0, 0, size.y / 2.0))]


func overview():
	var roads = []
	for road in layout.roads:
		for index in road.line.size() - 1:
			var a: Vector2 = road.line[index]
			var b: Vector2 = road.line[index + 1]
			roads.append(Vector4(a.x, a.y, b.x, b.y))
	var fields = []
	for field in _fields():
		fields.append(field.centre)
	return {
		"fields": fields,
		"ridges": [],
		"radius": 0.0,
		"relays": [],
		"roads": roads,
		"road_width": 6.0,
		"points_of_interest": layout.sites,
		"water": [],
		"water_radius": 0.0,
	}


func _resize_terrain():
	var ground = get_node_or_null("Geometry/Terrain")
	if ground != null and ground.mesh is PlaneMesh:
		super()


func _build_ground():
	layout = Registry.layout(scene_file_path)
	assert(not layout.is_empty(), "No battlefield definition for %s" % scene_file_path)
	size = layout.size
	terrain = TerrainModel.new(layout)
	var ground: MeshInstance3D = $Geometry/Terrain
	ground.mesh = TerrainMesh.build_mesh(terrain, layout.id)
	var material = ShaderMaterial.new()
	material.shader = GROUND_SHADER
	Palettes.configure(material, layout.biome, layout.get("palette", {}))
	material.set_shader_parameter(
		"control", ImageTexture.create_from_image(TerrainMesh.build_control(terrain, layout))
	)
	material.set_shader_parameter("map_size", size)
	material.set_shader_parameter("tier_step", terrain.tier_step)
	ground.mesh.surface_set_material(0, material)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The anti-aliasing backdrop must stay below the lowest basin.
	$Geometry/BlackBackgroundFixingAntiAliasingBug.position.y = terrain.min_height - 2.0
	var markers = $SpawnPoints
	for index in layout.bases.size():
		var marker: Marker3D
		if index < markers.get_child_count():
			marker = markers.get_child(index)
		else:
			marker = Marker3D.new()
			marker.name = "Start%d" % (index + 1)
			markers.add_child(marker)
		marker.position = ground_point(layout.bases[index].start)


# Every field in save order: home fields per start, then expansions.
func _fields() -> Array:
	var fields = []
	for base in layout.bases:
		fields.append({"site": base.start, "centre": base.field, "kind": "home"})
	for expansion in layout.expansions:
		fields.append(
			{
				"site": expansion.site,
				"centre": expansion.field,
				"kind": "rich" if expansion.get("rich", false) else "expansion"
			}
		)
	return fields


func _place_fields():
	for field in _fields():
		var stocks = STOCKS[field.kind]
		var points = field_points(field.site, field.centre)
		for index in points.size():
			var electronics = index >= MATERIAL_PILES
			var deposit = (RESOURCE_B if electronics else RESOURCE_A).instantiate()
			deposit.set(
				"resource_b" if electronics else "resource_a", stocks[1 if electronics else 0]
			)
			deposit.position = ground_point(points[index])
			deposit.harvest_origin = ground_point(field.centre)
			$Resources.add_child(deposit)


# Piles curve around the site at the field's distance, materials in the
# middle and electronics at both ends, leaving the far side open for workers.
static func field_points(site: Vector2, centre: Vector2) -> Array:
	var radius = site.distance_to(centre)
	var heading = (centre - site).angle()
	var step = PILE_SPACING / radius
	var points = []
	for index in MATERIAL_PILES:
		var angle = heading + (index - (MATERIAL_PILES - 1) / 2.0) * step
		points.append(site + Vector2.from_angle(angle) * radius)
	for side in [-1, 1]:
		var angle = heading + side * ((MATERIAL_PILES - 1) / 2.0 + 1.3) * step
		points.append(site + Vector2.from_angle(angle) * (radius + 0.6))
	return points


func _place_water(water: Dictionary):
	var ford = water.get("ford", false)
	var level = water.get("level", 0.0) - (FORD_SURFACE_DROP if ford else WATER_SURFACE_DROP)
	var polygon = _upward(water.polygon)
	var vertices = PackedVector3Array()
	for index in Geometry2D.triangulate_polygon(polygon):
		vertices.append(Vector3(polygon[index].x, level, polygon[index].y))
	var surface = _flat_mesh(vertices)
	var material = ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("hot", water.get("hot", false))
	surface.material_override = material
	surface.name = "Ford" if ford else "Water"
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Decorations.add_child(surface)


func _place_blocker(blocker: Dictionary):
	var polygon: PackedVector2Array = blocker.polygon
	var base = INF
	for point in polygon:
		base = minf(base, terrain.height_at(point))
	var body = Node3D.new()
	body.name = "Formation%d" % $Decorations.get_child_count()
	body.set_meta("solid_polygon", polygon)
	body.set_meta("sight_height", base + blocker.height)
	$Decorations.add_child(body)
	# Placeholder geometry until a kit dresses the formation.
	var material = StandardMaterial3D.new()
	material.albedo_color = Palettes.PALETTES.get(layout.biome, Palettes.PALETTES.desert).rock
	material.roughness = 0.9
	var prism = _prism(_upward(polygon), base - 0.5, base + blocker.height)
	prism.material_override = material
	body.add_child(prism)


func _place_forests():
	var variants = Vegetation.TREES.get(layout.biome, Vegetation.TREES.desert)
	var batches = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = ("%s-forest" % layout.id).hash()
	for forest in layout.forests:
		var spacing = 3.4 / sqrt(clampf(forest.get("density", 0.5), 0.1, 1.0))
		var polygon: PackedVector2Array = forest.polygon
		var bounds = Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			bounds = bounds.expand(point)
		for x in range(int(bounds.size.x / spacing) + 1):
			for z in range(int(bounds.size.y / spacing) + 1):
				var point = (
					bounds.position
					+ Vector2(x, z) * spacing
					+ Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * spacing * 0.8
				)
				if not Geometry2D.is_point_in_polygon(point, polygon):
					continue
				var variant = variants[rng.randi() % variants.size()]
				if not batches.has(variant):
					batches[variant] = []
				var scale = rng.randf_range(0.8, 1.15)
				batches[variant].append(
					Transform3D(
						Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale),
						ground_point(point)
					)
				)
	var cover = Node3D.new()
	cover.name = "Forests"
	add_child(cover)
	for variant in batches:
		MeshBatch.add(
			cover, MeshBatch.merged_mesh(variant, 6.5), batches[variant], variant.get_file(), true
		)


# Counter-clockwise outlines (in Godot's 2D sense) triangulate to faces that
# point up; authored polygons may use either orientation.
static func _upward(polygon: PackedVector2Array) -> PackedVector2Array:
	if Geometry2D.is_polygon_clockwise(polygon):
		var reversed = polygon.duplicate()
		reversed.reverse()
		return reversed
	return polygon


static func _flat_mesh(vertices: PackedVector3Array) -> MeshInstance3D:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	return instance


static func _prism(polygon: PackedVector2Array, bottom: float, top: float) -> MeshInstance3D:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in Geometry2D.triangulate_polygon(polygon):
		tool.add_vertex(Vector3(polygon[index].x, top, polygon[index].y))
	for index in polygon.size():
		var a = polygon[index]
		var b = polygon[(index + 1) % polygon.size()]
		var quad = [
			Vector3(a.x, top, a.y),
			Vector3(b.x, top, b.y),
			Vector3(b.x, bottom, b.y),
			Vector3(a.x, top, a.y),
			Vector3(b.x, bottom, b.y),
			Vector3(a.x, bottom, a.y)
		]
		for vertex in quad:
			tool.add_vertex(vertex)
	tool.generate_normals()
	var instance = MeshInstance3D.new()
	instance.mesh = tool.commit()
	return instance
