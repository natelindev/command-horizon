extends "res://source/match/Map.gd"

const Landmarks = preload("res://source/match/maps/IndustrialLandmarks.gd")
const BLOCKS = [Vector2(52, 37), Vector2(52, 67), Vector2(76, 37), Vector2(76, 67)]
const OUTBUILDINGS = [Vector2(52, 8), Vector2(76, 96)]
const ASSETS = ["SawtoothWorkshop", "CoolingHall", "ServiceOffice", "DamagedWarehouse"]
const FIELDS = [Vector2(14, 62), Vector2(114, 42), Vector2(32, 90), Vector2(96, 14)]
const RELAYS = [Vector2(64, 14), Vector2(64, 90)]
const ROADS = [
	Vector4(4, 22, 124, 22),
	Vector4(4, 52, 124, 52),
	Vector4(4, 82, 124, 82),
	Vector4(40, 14, 40, 90),
	Vector4(64, 14, 64, 90),
	Vector4(88, 14, 88, 90)
]
var exterior
var relays = []
var flight_obstacles = []


func overview():
	var buildings = []
	for point in BLOCKS:
		buildings.append(Rect2(point - Vector2(5.55, 5.3), Vector2(11.1, 10.6)))
	for point in OUTBUILDINGS:
		buildings.append(Rect2(point - Vector2(4.16, 3.97), Vector2(8.32, 7.94)))
	return {
		"ridges": [],
		"radius": 0,
		"fields": FIELDS,
		"relays": RELAYS,
		"buildings": buildings,
		"roads": ROADS
	}


func _ready():
	_atmosphere()
	var material = $Geometry/Terrain.mesh.material.duplicate()
	var roads = PackedVector4Array(ROADS)
	roads.resize(8)
	for index in 3:
		roads[index].x = -46
		roads[index].z = 174
	material.set_shader_parameter("roads", roads)
	material.set_shader_parameter("district_wear", true)
	$Geometry/Terrain.mesh.material = material
	exterior = load("res://source/match/maps/IndustrialBackdrop.gd").new()
	add_child(exterior)
	for index in BLOCKS.size():
		var point = BLOCKS[index]
		flight_obstacles.append(
			Landmarks.place($Decorations, Vector3(point.x, 0, point.y), ASSETS[index])
		)
	for index in OUTBUILDINGS.size():
		var point = OUTBUILDINGS[index]
		flight_obstacles.append(
			Landmarks.place($Decorations, Vector3(point.x, 0, point.y), ASSETS[index * 2], 6.0, .75)
		)
	for body in flight_obstacles:
		load("res://source/match/maps/IndustrialMaterials.gd").weather(body)
	for index in FIELDS.size():
		var point = FIELDS[index]
		var mirror = 1 if index % 2 == 0 else -1
		for offset in [
			Vector2(-3.5, 0),
			Vector2.ZERO,
			Vector2(3.5, 0),
			Vector2(-1.75, -3.5),
			Vector2(1.75, -3.5)
		]:
			var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			deposit.resource_a = 400 if index < 2 else 600
			deposit.position = Vector3(point.x + offset.x, 0, point.y + offset.y * mirror)
			$Resources.add_child(deposit)
		for extra in 2:
			var electronics = (
				load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
			)
			electronics.resource_b = 720 if index < 2 else 1200
			electronics.position = Vector3(
				point.x + mirror * 6.5, 0, point.y + mirror * (-2 if index < 2 else 2)
			)
			electronics.position += Vector3(0, 0, mirror * 3.5) * extra
			$Resources.add_child(electronics)
	for index in RELAYS.size():
		var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
		relay.name = "NorthRelay" if index == 0 else "SouthRelay"
		relay.label_title = "NORTH RELAY" if index == 0 else "SOUTH RELAY"
		relay.position = Vector3(RELAYS[index].x, 0, RELAYS[index].y)
		add_child(relay)
		relays.append(relay)


func _atmosphere():
	var game = get_parent()
	game.get_node("Fog").hide()
	var world = game.get_node("WorldEnvironment")
	world.environment = world.environment.duplicate()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("acbdc5")
	world.environment.ambient_light_energy = .5
	world.environment.tonemap_exposure = .9
	var sunlight = game.get_node("DirectionalLight3D")
	sunlight.light_color = Color("ffe3b9")
	sunlight.light_energy = 1.15
	sunlight.shadow_normal_bias = 2.0
	sunlight.shadow_blur = .5
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", .22)


func flight_height_at(point, baseline):
	return Landmarks.flight_height(flight_obstacles, point, baseline)


func capture_state(reference):
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
	for index in relays.size():
		var saved = state.relays[index]
		var relay = relays[index]
		relay.captured_by = entities.get(saved.owner)
		relay.candidate = entities.get(saved.candidate)
		relay.progress = saved.progress
		relay.contested = saved.contested
		relay._update_presentation()
