extends "res://source/match/Map.gd"

const Obstacle = preload("res://source/match/units/traits/MovementObstacle.tscn")
const RIDGES = [Vector2(54, 31), Vector2(65, 31), Vector2(63, 65), Vector2(74, 65)]
const RADIUS = 5.8
const SHELVES = ["SandstoneShelfA", "SandstoneShelfB", "SandstoneShelfC", "SandstoneShelfD"]
const ROADS = [
	Vector4(24, 26, 43, 48),
	Vector4(43, 48, 85, 48),
	Vector4(85, 48, 104, 70),
	Vector4(24, 26, 40, 12),
	Vector4(40, 12, 88, 12),
	Vector4(88, 12, 104, 70),
	Vector4(24, 26, 40, 84),
	Vector4(40, 84, 88, 84),
	Vector4(88, 84, 104, 70),
	Vector4(14, 43, 24, 26),
	Vector4(114, 53, 104, 70),
	Vector4(52, 6, 52, 12),
	Vector4(76, 90, 76, 84)
]

const FIELDS = [Vector2(14, 43), Vector2(114, 53), Vector2(52, 6), Vector2(76, 90)]
const DesertMaterials = preload("res://source/match/maps/DesertMaterials.gd")
const TREES = DesertMaterials.TREES
var exterior


func overview():
	return {
		"ridges": RIDGES,
		"radius": RADIUS,
		"fields": FIELDS,
		"relays": [],
		"roads": ROADS,
		"road_width": 5.2
	}


func _ready():
	# Rotationally paired fields give both starts the same opening economy.
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
		_escarpment(RIDGES[index], index)
	var material = $Geometry/Terrain.mesh.material.duplicate()
	var roads = PackedVector4Array(ROADS)
	roads.resize(16)
	material.set_shader_parameter("roads", roads)
	material.set_shader_parameter("road_count", ROADS.size())
	$Geometry/Terrain.mesh.material = material
	_ground_cover()
	_atmosphere()
	exterior = load("res://source/match/maps/DesertBackdrop.gd").new()
	add_child(exterior)


func _escarpment(point, index):
	var rock = Node3D.new()
	rock.name = "SandstoneShelf%d" % index
	rock.position = Vector3(point.x, 0, point.y)
	var model = load("res://assets/models/environment/desert/%s.glb" % SHELVES[index]).instantiate()
	model.name = "Model"
	DesertMaterials.weather_stone(model)
	rock.add_child(model)
	var obstacle = Obstacle.instantiate()
	obstacle.radius = RADIUS
	obstacle.affect_navigation_mesh = true
	obstacle.path_height_offset = 0.6
	obstacle.sight_height = 1.15
	rock.add_child(obstacle)
	$Decorations.add_child(rock)


func _atmosphere():
	var game = get_parent()
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", 0.22)


func _ground_cover():
	var cover = Node3D.new()
	cover.name = "DesertGroundCover"
	add_child(cover)
	var tree_index = 0
	for point in [
		Vector2(43, 25),
		Vector2(46, 35),
		Vector2(74, 23),
		Vector2(79, 36),
		Vector2(49, 68),
		Vector2(58, 75),
		Vector2(87, 64),
		Vector2(83, 72),
		Vector2(8, 12),
		Vector2(12, 16),
		Vector2(116, 83),
		Vector2(120, 86)
	]:
		var plant = (
			load("res://assets/models/environment/desert/%s.glb" % TREES[tree_index % TREES.size()])
			. instantiate()
		)
		plant.position = Vector3(point.x, 0.01, point.y)
		plant.scale = Vector3.ONE * (0.85 + (tree_index % 3) * 0.12)
		plant.rotation.y = point.x * 0.27
		cover.add_child(plant)
		tree_index += 1
