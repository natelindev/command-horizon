extends "res://source/match/Map.gd"

const SHORE = [
	Vector2(0, 15),
	Vector2(18, 11),
	Vector2(36, 14),
	Vector2(48, 19),
	Vector2(48, 49),
	Vector2(52, 58),
	Vector2(76, 58),
	Vector2(80, 49),
	Vector2(80, 19),
	Vector2(92, 14),
	Vector2(110, 11),
	Vector2(128, 15),
	Vector2(128, 104),
	Vector2(0, 104)
]
const FIELDS = [Vector2(16, 46), Vector2(112, 46), Vector2(24, 81), Vector2(104, 81)]
const ROADS = [
	Vector4(16, 34, 30, 34),
	Vector4(30, 34, 30, 94),
	Vector4(30, 64, 98, 64),
	Vector4(30, 94, 98, 94),
	Vector4(98, 34, 98, 94),
	Vector4(98, 34, 112, 34),
	Vector4(64, 64, 64, 94)
]
const FOUNDRIES = [Vector2(54, 80), Vector2(74, 80)]
const CRANES = [Vector2(42, 30), Vector2(86, 30)]
const BEACONS = [Vector2(40, 19), Vector2(88, 19)]
const PINES = [Vector2(8, 65), Vector2(120, 65), Vector2(8, 96), Vector2(120, 96)]
var flight_obstacles = []
var water_material
var exterior


class WaterSightVolume:
	extends Node
	var radius = 7.0
	var sight_height = 4.4

	func _ready():
		add_to_group("sight_blockers")


func overview():
	var buildings = []
	for point in FOUNDRIES:
		buildings.append(Rect2(point - Vector2(5.55, 5.3), Vector2(11.1, 10.6)))
	for point in CRANES:
		buildings.append(Rect2(point - Vector2(2.7, 2.8), Vector2(5.4, 5.6)))
	return {
		"ridges": PINES,
		"radius": 3.6,
		"fields": FIELDS,
		"relays": [],
		"roads": ROADS,
		"buildings": buildings,
		"land": SHORE
	}


func _ready():
	_atmosphere()
	_ground_and_water()
	_quays()
	for index in 2:
		_landmark(
			"industrial/%s" % ["SawtoothWorkshop", "CoolingHall"][index], FOUNDRIES[index], 8.0, 6.9
		)
		var crane = _landmark("coastal/HarborCrane", CRANES[index], 7.0, 8.2)
		crane.get_node("Model").rotation.y = PI * index
		_landmark("coastal/HarborBeacon", BEACONS[index], 3.0, 7.5)
	for point in PINES:
		_landmark("coastal/CoastalPineStand", point, 3.6, 5.5)
	_landmark("coastal/CargoBarge", Vector2(76, 34), 7.0, 4.4, false)
	_resources()
	exterior = load("res://source/match/maps/CoastalBackdrop.gd").new()
	add_child(exterior)
	_port_details()
	_update_water()


func _physics_process(_delta):
	_update_water()


func _update_water():
	water_material.set_shader_parameter("simulation_time", get_parent().simulation_time)


func restore_state(_state, _entities):
	# Loaded battles remain paused; derive the initial water pose from their clock.
	_update_water()


func is_land(point):
	return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), PackedVector2Array(SHORE))


func _ground_and_water():
	$Geometry/BlackBackgroundFixingAntiAliasingBug.position.y = -2.0
	var material = $Geometry/Terrain.mesh.material.duplicate()
	var roads = PackedVector4Array(ROADS)
	roads.resize(8)
	material.set_shader_parameter("roads", roads)
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	var triangles = Geometry2D.triangulate_polygon(PackedVector2Array(SHORE))
	for index in range(0, triangles.size(), 3):
		for corner in [0, 1, 2]:
			var point = SHORE[triangles[index + corner]]
			surface.set_normal(Vector3.UP)
			surface.set_uv(point / size)
			surface.add_vertex(Vector3(point.x, 0, point.y))
	$Geometry/Terrain.mesh = surface.commit()
	var water = MeshInstance3D.new()
	water.name = "HarborWater"
	var plane = PlaneMesh.new()
	plane.size = size + Vector2(92, 92)
	plane.center_offset = Vector3(size.x / 2, -.65, size.y / 2)
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://source/shaders/3d/coastal_water.gdshader")
	var coastline = PackedVector4Array()
	for index in 11:
		coastline.append(
			Vector4(SHORE[index].x, SHORE[index].y, SHORE[index + 1].x, SHORE[index + 1].y)
		)
	coastline.resize(16)
	water_material.set_shader_parameter("shoreline", coastline)
	plane.material = water_material
	water.mesh = plane
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Geometry.add_child(water)


func _quays():
	for index in range(3, 8):
		var a = Vector3(SHORE[index].x, 0, SHORE[index].y)
		var b = Vector3(SHORE[index + 1].x, 0, SHORE[index + 1].y)
		var wall = _box(
			(a + b) / 2 + Vector3(0, -.68, 0),
			Vector3(.65, 1.65, a.distance_to(b) + .15),
			Color("75827d")
		)
		wall.rotation.y = atan2(b.x - a.x, b.z - a.z)
		var cap = _box(
			(a + b) / 2 + Vector3(0, .15, 0),
			Vector3(.82, .12, a.distance_to(b) + .15),
			Color("a9aca0")
		)
		cap.rotation.y = wall.rotation.y
		var count = floori(a.distance_to(b) / 4)
		for post in range(1, count):
			_box(
				a.lerp(b, float(post) / count) + Vector3(0, -.2, 0),
				Vector3(.22, .95, .22),
				Color("34484c")
			)
	for point in [
		Vector2(47.4, 24),
		Vector2(47.4, 42),
		Vector2(56, 58.6),
		Vector2(72, 58.6),
		Vector2(80.6, 42),
		Vector2(80.6, 24)
	]:
		_box(Vector3(point.x, .25, point.y), Vector3(.34, .5, .34), Color("d1a13d"))


func _box(point, dimensions, color):
	var model = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = dimensions
	model.mesh = shape
	model.position = point
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .85
	model.material_override = material
	$Decorations.add_child(model)
	return model


func _landmark(asset, point, radius, height, ground = true):
	var body = Node3D.new()
	body.name = asset.get_file()
	body.position = Vector3(point.x, 0, point.y)
	body.set_meta("clearance_radius", radius)
	body.set_meta("clearance_height", height)
	$Decorations.add_child(body)
	var model = load("res://assets/models/environment/%s.glb" % asset).instantiate()
	model.name = "Model"
	load("res://source/match/maps/CoastalMaterials.gd").weather(model)
	body.add_child(model)
	if ground:
		var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
		obstacle.radius = radius
		obstacle.sight_height = height
		obstacle.affect_navigation_mesh = true
		body.add_child(obstacle)
	else:
		# A moored ship blocks sight and has air clearance, but never snaps to land
		# or reserves a circular patch of walkable quay as a ground obstacle.
		var obstacle = WaterSightVolume.new()
		obstacle.radius = radius
		obstacle.sight_height = height
		body.add_child(obstacle)
	flight_obstacles.append(body)
	return body


func _resources():
	for index in FIELDS.size():
		var point = FIELDS[index]
		var mirror = 1 if index % 2 == 0 else -1
		for offset in [-3.5, 0.0, 3.5]:
			var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			deposit.resource_a = 200 if index < 2 else 300
			deposit.position = Vector3(point.x + offset, 0, point.y)
			$Resources.add_child(deposit)
		var electronics = load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
		electronics.resource_b = 240 if index < 2 else 400
		electronics.position = Vector3(
			point.x + mirror * 6.5, 0, point.y + (-2 if index < 2 else 2)
		)
		$Resources.add_child(electronics)


func flight_height_at(point, baseline):
	var height = baseline
	for body in flight_obstacles:
		var radius = body.get_meta("clearance_radius")
		var distance = Vector2(point.x - body.position.x, point.z - body.position.z).length()
		var rise = 1.0 - smoothstep(radius + 1.9, radius + 10.4, distance)
		height = maxf(height, lerpf(baseline, body.get_meta("clearance_height") + 1.1, rise))
	return height


func _atmosphere():
	var game = get_parent()
	game.get_node("Fog").hide()
	var world = game.get_node("WorldEnvironment")
	world.environment = world.environment.duplicate()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a3c3cf")
	world.environment.ambient_light_energy = .5
	world.environment.tonemap_exposure = .9
	var light = game.get_node("DirectionalLight3D")
	light.light_color = Color("fff0d7")
	light.light_energy = 1.10
	light.shadow_normal_bias = 1.4
	light.shadow_blur = .6
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", .22)


func _port_details():
	# Equipment stays inside existing solid landmark envelopes, below their roofs.
	for point in CRANES:
		for offset in [Vector3(-2.8, 0.4, 2.6), Vector3(-3.7, 0.25, 2.8)]:
			_box(
				Vector3(point.x, 0, point.y) + offset,
				Vector3(.9, offset.y * 2, .9),
				Color("65766b")
			)
	for point in FOUNDRIES:
		for offset in [Vector3(-3.4, .4, -4.5), Vector3(3.4, .4, -4.5)]:
			_box(Vector3(point.x, 0, point.y) + offset, Vector3(1.8, .8, .6), Color("737971"))
