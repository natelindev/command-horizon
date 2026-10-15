extends "res://source/match/Map.gd"

const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")
const RIDGES = [
	Vector2(64, 12),
	Vector2(64, 24),
	Vector2(64, 49),
	Vector2(64, 61),
	Vector2(64, 86),
	Vector2(64, 98)
]
const RIDGE_RADIUS = 6.5
const FIELDS = [Vector2(13, 34), Vector2(115, 70), Vector2(30, 58), Vector2(98, 46)]
const RELAYS = [Vector2(55, 36), Vector2(73, 73)]
const SHELF_MODELS = [
	"GlacialShelfA",
	"GlacialShelfB",
	"GlacialShelfC",
	"GlacialShelfD",
	"GlacialShelfB",
	"GlacialShelfA"
]
const ROADS = [
	Vector4(17, 18, 32, 36),
	Vector4(32, 36, 88, 36),
	Vector4(88, 36, 111, 86),
	Vector4(17, 18, 24, 73),
	Vector4(24, 73, 96, 73),
	Vector4(96, 73, 111, 86),
	Vector4(13, 34, 27, 34),
	Vector4(115, 70, 105, 70),
	Vector4(30, 58, 28, 73),
	Vector4(98, 46, 92, 46)
]
var relays = []
var exterior


func overview():
	return {
		"ridges": RIDGES,
		"radius": RIDGE_RADIUS,
		"fields": FIELDS,
		"relays": RELAYS,
		"roads": ROADS,
		"road_width": 6.5
	}


func _ready():
	_configure_atmosphere()
	for index in FIELDS.size():
		var anchor = FIELDS[index]
		var mirror = 1 if index % 2 == 0 else -1
		for offset in [
			Vector2(-2.5, 0), Vector2.ZERO, Vector2(2.5, 0), Vector2(-1.5, -3), Vector2(1.5, -3)
		]:
			var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			deposit.resource_a = 400 if index < 2 else 600
			deposit.position = Vector3(anchor.x + offset.x, 0, anchor.y + offset.y * mirror)
			$Resources.add_child(deposit)
		for extra in 2:
			var electronics = (
				load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
			)
			electronics.resource_b = 720 if index < 2 else 1200
			electronics.position = Vector3(anchor.x + 5.5 * mirror, 0, anchor.y + 2 * mirror)
			electronics.position += Vector3(0, 0, mirror * 3) * extra
			$Resources.add_child(electronics)
	for index in RIDGES.size():
		_ridge(RIDGES[index], index)
	for index in RELAYS.size():
		var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
		relay.name = "NorthRelay" if index == 0 else "SouthRelay"
		relay.label_title = "NORTH RELAY" if index == 0 else "SOUTH RELAY"
		relay.position = Vector3(RELAYS[index].x, 0, RELAYS[index].y)
		add_child(relay)
		relays.append(relay)
	var material = $Geometry/Terrain.mesh.material.duplicate()
	var roads = PackedVector4Array(ROADS)
	roads.resize(16)
	material.set_shader_parameter("roads", roads)
	material.set_shader_parameter("road_count", ROADS.size())
	$Geometry/Terrain.mesh.material = material
	_ground_cover()
	exterior = load("res://source/match/maps/AlpineBackdrop.gd").new()
	add_child(exterior)


func _configure_atmosphere():
	var game = get_parent()
	var camera = game.get_node("IsometricCamera3D")
	camera.visible_height_max = 24
	camera._align_camera_properties_to_current_size()
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", 0.18)


func _ridge(point, index):
	var rock = Node3D.new()
	rock.name = "GlacialRidge%d" % index
	rock.position = Vector3(point.x, 0, point.y)
	# Imported granite and utility remnants fit the existing low ridge envelope.
	var model = (
		load("res://assets/models/environment/alpine/%s.glb" % SHELF_MODELS[index]).instantiate()
	)
	model.name = "Model"
	model.rotation.y = [0.0, 0.35, -0.25, 0.2, -0.6, 0.8][index]
	load("res://source/match/maps/AlpineMaterials.gd").weather(model)
	rock.add_child(model)
	var obstacle = Obstacle.instantiate()
	obstacle.radius = RIDGE_RADIUS
	obstacle.affect_navigation_mesh = true
	obstacle.path_height_offset = 0.6
	obstacle.sight_height = 1.15
	rock.add_child(obstacle)
	$Decorations.add_child(rock)


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


func _ground_cover():
	var cover = Node3D.new()
	cover.name = "AlpineGroundCover"
	add_child(cover)
	for point in [
		Vector2(10, 8),
		Vector2(30, 11),
		Vector2(42, 23),
		Vector2(44, 53),
		Vector2(45, 91),
		Vector2(21, 87),
		Vector2(90, 13),
		Vector2(106, 25),
		Vector2(88, 56),
		Vector2(84, 86),
		Vector2(99, 95),
		Vector2(118, 96)
	]:
		var model = load("res://assets/models/environment/alpine/WinterSedge.glb").instantiate()
		model.position = Vector3(point.x, 0.006, point.y)
		model.rotation.y = point.x * 0.31
		cover.add_child(model)
