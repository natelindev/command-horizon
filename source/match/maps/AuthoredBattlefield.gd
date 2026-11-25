extends "res://source/match/Map.gd"

# Builds an authored, elevated battlefield from its definition (see
# BattlefieldRegistry): gameplay terrain, rendered ground, water, solid
# formations, forests, resource fields and start markers. Gameplay queries
# (height, tier, navigation source) answer from the same TerrainModel.

const Registry = preload("res://source/match/maps/terrain/BattlefieldRegistry.gd")
const TerrainModel = preload("res://source/match/maps/terrain/TerrainModel.gd")
const TerrainMesh = preload("res://source/match/maps/terrain/TerrainMesh.gd")
const Palettes = preload("res://source/match/maps/terrain/BiomePalettes.gd")
const RESOURCE_A = preload("res://source/match/units/non-player/ResourceA.tscn")
const RESOURCE_B = preload("res://source/match/units/non-player/ResourceB.tscn")
const GROUND_SHADER = preload("res://source/shaders/3d/authored_terrain.gdshader")
const WaterSurface = preload("res://source/match/maps/terrain/WaterSurface.gd")
const WATER_SHADER = preload("res://source/shaders/3d/authored_water.gdshader")
const LAVA_SHADER = preload("res://source/shaders/3d/authored_lava.gdshader")
const ROCK_SHADER = preload("res://source/shaders/3d/canyon_rock.gdshader")
const CliffMesh = preload("res://source/match/maps/terrain/CliffMesh.gd")
const TerrainDressing = preload("res://source/match/maps/terrain/TerrainDressing.gd")
const TerrainBackdrop = preload("res://source/match/maps/terrain/TerrainBackdrop.gd")
const IndustrialLandmarks = preload("res://source/match/maps/IndustrialLandmarks.gd")
# Materials and electronics stock per deposit for each kind of field.
const STOCKS = preload("res://source/match/economy/ResourceFieldStocks.gd").STOCKS
const CAMPAIGN_STOCKS = {"home": [400, 720], "expansion": [600, 1200], "rich": [900, 1800]}
# Five material piles then two electronics nodes on an arc around the site
# where a headquarters stands (or can be built).
const PILE_SPACING = 2.6
const MATERIAL_PILES = 5
const ELECTRONICS_NODES = 2
const WATER_SURFACE_DROP = 0.3
const FORD_SURFACE_DROP = 0.08

var water_flow
var layout = {}
var terrain = null
var points_of_interest = []
# Capturable relays that grant local vision (maps that define them).
var relays = []


func _enter_tree():
	if terrain == null and not Engine.is_editor_hint():
		_build_ground()
	super()


func _ready():
	if Engine.is_editor_hint():
		return
	_place_fields()
	_place_relays()
	_place_garrisons()
	water_flow = load("res://source/match/maps/terrain/WaterFlowField.gd").new()
	water_flow.build(layout)
	for water in layout.water:
		_place_water(water)
	_place_rock()
	TerrainDressing.populate(self)


func _place_relays():
	for entry in layout.get("relays", []):
		var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
		relay.name = entry.name.to_pascal_case()
		relay.label_title = entry.name.to_upper()
		relay.position = ground_point(entry.position)
		relay.path_height_offset = TerrainDressing.GROUND_OFFSET
		add_child(relay)
		relays.append(relay)


# Neutral buildings infantry can garrison. NeutralWorld adopts them in the
# order AmbientCatalog.structures() lists them; aircraft climb over them.
func _place_garrisons():
	for entry in layout.get("garrisons", []):
		var body = IndustrialLandmarks.place(
			$Decorations,
			ground_point(entry.position),
			entry.asset,
			entry.get("radius", 6.0),
			entry.get("scale", 1.0)
		)
		body.rotation.y = -deg_to_rad(TerrainDressing.heading(layout, entry))
		body.get_node("MovementObstacle").path_height_offset = TerrainDressing.GROUND_OFFSET
		interior_obstacles.append(body)


# Relay state is the map's skirmish mission; maps without relays have none.
func capture_state(reference):
	if relays.is_empty():
		return {}
	var state = {"relays": []}
	for relay in relays:
		state.relays.append(
			{
				"owner": reference.call(relay.captured_by),
				"candidate": reference.call(relay.candidate),
				"progress": relay.progress,
				"contested": relay.contested
			}
		)
	return state


func restore_state(state, entities):
	for index in mini(relays.size(), state.get("relays", []).size()):
		var saved = state.relays[index]
		var relay = relays[index]
		relay.captured_by = entities.get(saved.owner)
		relay.candidate = entities.get(saved.candidate)
		relay.progress = saved.progress
		relay.contested = saved.contested
		relay._update_presentation()


func height_at(point: Vector2) -> float:
	return terrain.height_at(point)


func tier_at(point: Vector2) -> int:
	return terrain.tier_at(point)


func max_height() -> float:
	return terrain.max_height


func min_height() -> float:
	return terrain.min_height


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
	# Previews call this on scenes that never entered the tree.
	if layout.is_empty():
		layout = Registry.layout(scene_file_path)
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
		"relays": layout.get("relays", []).map(func(relay): return relay.position),
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
	Palettes.configure(material, _ground_palette(), layout.get("palette", {}))
	TerrainTextures.configure(material, layout.get("texture_preset", layout.biome))
	material.set_shader_parameter(
		"control", ImageTexture.create_from_image(TerrainMesh.build_control(terrain, layout))
	)
	material.set_shader_parameter("map_size", size)
	material.set_shader_parameter("tier_step", terrain.tier_step)
	ground.mesh.surface_set_material(0, material)
	# Ground and cliffs cast shadows so hills, dunes and ridges sculpt the map.
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var backdrop = MeshInstance3D.new()
	backdrop.name = "Backdrop"
	backdrop.mesh = TerrainBackdrop.build(terrain, layout.get("backdrop", {}), layout.id)
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Geometry.add_child(backdrop)
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


func _ground_palette() -> String:
	return layout.get("ground", layout.biome)


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
		var stocks = field_stocks()[field.kind]
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


func field_stocks() -> Dictionary:
	var game = find_parent("Match")
	return CAMPAIGN_STOCKS if game != null and not game.settings.mission_id.is_empty() else STOCKS


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
	# Ford footprints include dry approaches. A connected river carries the
	# shallow crossing in its own mesh, keeping one continuous flowing skin.
	if water.get("ford", false):
		for river in layout.water:
			if not river.get("ford", false) and not river.get("lava", false):
				if not Geometry2D.intersect_polygons(water.polygon, river.polygon).is_empty():
					return
	_place_water_surface(water)


func _place_water_surface(water: Dictionary):
	var ford = water.get("ford", false)
	var level = water.get("level", 0.0) - (FORD_SURFACE_DROP if ford else WATER_SURFACE_DROP)
	var polygon = _upward(water.polygon)
	var surface: MeshInstance3D
	var material = ShaderMaterial.new()
	if water.get("lava", false):
		var vertices = PackedVector3Array()
		for index in Geometry2D.triangulate_polygon(polygon):
			vertices.append(Vector3(polygon[index].x, level, polygon[index].y))
		surface = _flat_mesh(vertices)
		material.shader = LAVA_SHADER
	else:
		var builder = WaterSurface.new()
		var definition = water.duplicate()
		definition.polygon = polygon
		surface = MeshInstance3D.new()
		surface.mesh = builder.build(definition, layout.water, level)
		surface.extra_cull_margin = .4
		material.shader = WATER_SHADER
		material.set_shader_parameter("flow_field", water_flow.texture)
		material.set_shader_parameter("flow_map_size", water_flow.size)
		material.set_shader_parameter("has_flow_field", true)
		material.set_shader_parameter("flow_speed", builder.speed)
		material.set_shader_parameter("wave_height", .012 if ford else .065)
		Palettes.configure_water(material, _ground_palette())
	surface.material_override = material
	surface.name = "Lava" if water.get("lava", false) else ("Ford" if ford else "Water")
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Decorations.add_child(surface)


# Cliffs along every tier edge and ramp cut, and solid formations, in one
# mesh with the biome's rock material, plus one mesh per other named rock.
func _place_rock():
	for variant in CliffMesh.variants(layout):
		var mesh = CliffMesh.build(terrain, layout, layout.id, variant)
		if mesh == null:
			continue
		var rock = MeshInstance3D.new()
		rock.name = "Rock" if variant == "" else "Rock" + variant.to_pascal_case()
		rock.mesh = mesh
		var material = ShaderMaterial.new()
		material.shader = ROCK_SHADER
		load("res://source/match/ObjectMaterials.gd").configure_rock(
			material, "concrete" if variant == "ice" else "stone", .12 if variant == "ice" else .65
		)
		var rock_colours = Palettes.rock(variant if variant != "" else _ground_palette())
		rock_colours = rock_colours.duplicate()
		if variant == "":
			rock_colours.merge(layout.get("rock", {}), true)
		for key in rock_colours:
			material.set_shader_parameter(key, rock_colours[key])
		rock.material_override = material
		$Decorations.add_child(rock)


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
