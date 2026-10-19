extends "res://source/match/Map.gd"

const Catalog = preload("res://source/match/maps/BattlefieldCatalog.gd")
const Opening = preload("res://source/match/maps/StartingResourceLayout.gd")
const Vegetation = preload("res://source/match/maps/Vegetation.gd")
const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")

@export var map_id = "RedrockDivide"
var points_of_interest = []


func overview():
	var data = Catalog.MAPS[map_id]
	return {
		"fields": data.fields,
		"ridges": data.ridges,
		"radius": data.radius,
		"relays": [],
		"roads": data.roads,
		"road_width": 6.0,
		"points_of_interest": data.sites,
		"water": data.water,
		"water_radius": data.water_radius,
		"water_color": Color("b15a24") if data.surface == 4 else Color("315e68"),
		"low": data.low,
		"high": data.high
	}


func _ready():
	var data = Catalog.MAPS[map_id]
	_terrain(data)
	_fields(data)
	for index in data.ridges.size():
		var point = data.ridges[index]
		var height = 9.0 if data.biome == "temperate" else 6.5
		var body = _obstacle(point, data.radius, height)
		body.name = "Landmark%d" % index
		var model = (
			load("res://assets/models/environment/%s.glb" % data.models[index % data.models.size()])
			. instantiate()
		)
		# Keep imported art within its navigation footprint, including tall cranes.
		Vegetation.fit_height(model, height)
		Vegetation.fit_footprint(model, data.radius)
		model.rotation.y = index * TAU / data.players
		body.add_child(model)
		interior_obstacles.append(body)
	for point in data.water:
		_pool(point, data.water_radius, data.surface == 4)
	_ground_cover(data)


func _terrain(data):
	var ground = $Geometry/Terrain
	ground.mesh = ground.mesh.duplicate()
	var material = ShaderMaterial.new()
	material.shader = preload("res://source/shaders/3d/battlefield.gdshader")
	for key in ["low", "high", "road", "surface"]:
		material.set_shader_parameter(key, data[key])
	var roads = PackedVector4Array(data.roads)
	roads.resize(16)
	material.set_shader_parameter("roads", roads)
	material.set_shader_parameter("road_count", data.roads.size())
	ground.mesh.material = material


func _fields(data):
	for index in data.fields.size():
		var center: Vector2 = data.fields[index]
		# Tangential arcs follow each field's own position, preserving rotational symmetry.
		var forward: Vector2 = (size / 2 - center).normalized()
		# Crown's ring approaches follow diagonal passes rather than radial lanes.
		if map_id == "FrostboundCrown":
			forward = (size / 2 - data.starts[index % data.players]).normalized()
		var right = Vector2(forward.y, -forward.x)
		var offsets = Opening.offsets()
		for slot in offsets.size():
			var kind = "A" if slot < 5 else "B"
			var deposit = (
				load("res://source/match/units/non-player/Resource%s.tscn" % kind).instantiate()
			)
			var opening = index < data.players
			deposit.set(
				"resource_a" if slot < 5 else "resource_b",
				(400 if opening else 600) if slot < 5 else (720 if opening else 1200)
			)
			var point = center + right * offsets[slot].x + forward * offsets[slot].y
			deposit.position = Vector3(point.x, 0, point.y)
			deposit.harvest_origin = Vector3(center.x, 0, center.y)
			$Resources.add_child(deposit)


func _obstacle(point, radius, height):
	var body = Node3D.new()
	body.position = Vector3(point.x, 0, point.y)
	var obstacle = Obstacle.instantiate()
	obstacle.name = "MovementObstacle"
	obstacle.radius = radius
	obstacle.sight_height = height
	obstacle.path_height_offset = .6
	obstacle.affect_navigation_mesh = true
	body.add_child(obstacle)
	$Decorations.add_child(body)
	return body


func _pool(point, radius, volcanic):
	var body = _obstacle(point, radius, 0.0)
	body.name = "Caldera" if volcanic else "Water"
	var shore = StandardMaterial3D.new()
	shore.albedo_color = Catalog.MAPS[map_id].high.darkened(.25)
	shore.roughness = .95
	var rim = _pool_surface(radius, 0.0, shore)
	rim.position.y = .025
	body.add_child(rim)
	var material = ShaderMaterial.new()
	material.shader = preload("res://source/shaders/3d/battlefield_water.gdshader")
	material.set_shader_parameter("hot", volcanic)
	var water = _pool_surface(radius, .75, material)
	water.position.y = .035
	body.add_child(water)
	# Small shore rocks sit inside the already blocked footprint.
	for index in 5:
		var angle = index * TAU / 5.0 + .3
		var point_on_shore = Vector3(cos(angle), 0, sin(angle)) * (radius * .94 - .2)
		var biome = Catalog.MAPS[map_id].biome
		var rock = (
			load(
				(
					"res://assets/models/environment/%s.glb"
					% ("alpine/GlacialShelfC" if biome == "alpine" else "desert/SandstoneShelfC")
				)
			)
			. instantiate()
		)
		Vegetation.fit_height(rock, .6 + (index % 3) * .2)
		Vegetation.fit_footprint(rock, 1.4)
		rock.position = point_on_shore
		rock.rotation.y = angle
		body.add_child(rock)


func _pool_surface(radius, inset, material):
	var vertices = PackedVector3Array([Vector3.ZERO])
	var normals = PackedVector3Array([Vector3.UP])
	var indices = PackedInt32Array()
	for index in 64:
		var angle = index * TAU / 64.0
		var shore = .94 + sin(angle * 3) * .03 + sin(angle * 7 + .4) * .02
		vertices.append(Vector3(cos(angle), 0, sin(angle)) * (radius * shore - inset))
		normals.append(Vector3.UP)
		indices.append_array([0, index + 1, (index + 1) % 64 + 1])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


func _ground_cover(data):
	# Deterministic decoration only; gameplay features are explicitly authored.
	var rng = RandomNumberGenerator.new()
	rng.seed = map_id.hash()
	var cover = Node3D.new()
	cover.name = "GroundCover"
	add_child(cover)
	for index in 160:
		var point = Vector2(rng.randf_range(5, size.x - 5), rng.randf_range(5, size.y - 5))
		if not _clear_scenery(point, data):
			continue
		var biome = data.biome if data.biome != "temperate" else "coastal"
		var model
		if index % 3 == 0:
			model = Vegetation.tree(biome, index, rng.randf_range(4.0, 6.5))
		else:
			var asset = "alpine/WinterSedge" if biome == "alpine" else "desert/DryScrub"
			model = load("res://assets/models/environment/%s.glb" % asset).instantiate()
			Vegetation.fit_height(model, .4 + rng.randf() * .5)
		model.position = Vector3(point.x, .01, point.y)
		model.rotation.y = rng.randf() * TAU
		cover.add_child(model)


# gdlint: disable=max-returns
func _clear_scenery(point, data):
	for start in data.starts:
		if point.distance_to(start) < 24:
			return false
	for field in data.fields:
		if point.distance_to(field) < 16:
			return false
	for site in data.sites:
		if point.distance_to(site.position) < 13:
			return false
	for rock in data.ridges:
		if point.distance_to(rock) < data.radius + 2:
			return false
	for pool in data.water:
		if point.distance_to(pool) < data.water_radius + 3:
			return false
	for road in data.roads:
		if (
			point.distance_to(
				Geometry2D.get_closest_point_to_segment(
					point, Vector2(road.x, road.y), Vector2(road.z, road.w)
				)
			)
			< 7
		):
			return false
	return true
