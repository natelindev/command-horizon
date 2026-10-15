extends "res://source/match/Map.gd"

const POINTS = [Vector3(64, 0, 100), Vector3(100, 0, 40), Vector3(170, 0, 40)]
const NAMES = ["South crossing", "Ridge depot", "Extraction"]
const ENTRIES = [Vector3(64, 0, 120), Vector3(100, 0, 12), Vector3(182, 0, 66)]
const LANDMARKS = [
	[Vector3(49, 0, 68), "RoadCutA"],
	[Vector3(79, 0, 51), "RoadPumpStation"],
	[Vector3(121, 0, 60), "RuinedTransferBay"],
	[Vector3(145, 0, 22), "RoadCutB"]
]
const KIT = "res://assets/models/environment/supply/"


func _ready():
	var route = [Vector3(18, 0, 100)] + POINTS
	var roads = PackedVector4Array()
	for index in 3:
		var a = route[index]
		var b = route[index + 1]
		roads.append(Vector4(a.x, a.z, b.x, b.z))
	var material = $Geometry/Terrain.mesh.material.duplicate()
	material.set_shader_parameter("roads", roads)
	material.set_shader_parameter(
		"checkpoints",
		PackedVector2Array(
			[
				Vector2(POINTS[0].x, POINTS[0].z),
				Vector2(POINTS[1].x, POINTS[1].z),
				Vector2(POINTS[2].x, POINTS[2].z)
			]
		)
	)
	$Geometry/Terrain.mesh.material = material
	for entry in LANDMARKS:
		_landmark(entry[0], entry[1])
	_roadside(route)
	add_child(load("res://source/match/maps/SupplyBackdrop.gd").new())
	_atmosphere()


func _landmark(point, asset):
	var landmark = Node3D.new()
	landmark.name = asset
	landmark.position = point
	var model = load(KIT + asset + ".glb").instantiate()
	model.name = "Model"
	# Keep the old obstacle's 0.6 m navigation alignment; ground the visible mesh.
	model.position.y = -0.6
	load("res://source/match/maps/DesertMaterials.gd").weather_stone(model)
	landmark.add_child(model)
	var obstacle = load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
	obstacle.radius = 5.0
	obstacle.affect_navigation_mesh = true
	landmark.add_child(obstacle)
	$Decorations.add_child(landmark)


func _roadside(route):
	var details = Node3D.new()
	details.name = "RoadsideDetails"
	add_child(details)
	for index in 3:
		var a = route[index]
		var b = route[index + 1]
		var direction = (b - a).normalized()
		var side = Vector3(-direction.z, 0, direction.x)
		for step in range(8, int(a.distance_to(b)) - 8, 11):
			for sign_value in [-1, 1]:
				var point = a + direction * step + side * (6.25 * sign_value)
				if POINTS.any(func(checkpoint): return point.distance_to(checkpoint) < 9):
					continue
				var asset = "DrainageRemnant" if step % 3 == 0 else "RoadSage"
				var model = load(KIT + asset + ".glb").instantiate()
				model.position = point + Vector3.UP * .01
				model.rotation.y = (
					atan2(direction.x, direction.z) + (PI / 2 if sign_value < 0 else 0)
				)
				details.add_child(model)
	for index in 3:
		var number = Label3D.new()
		number.text = "0%d" % (index + 1)
		number.font_size = 80
		number.pixel_size = .025
		number.modulate = Color("bdb494")
		number.outline_size = 0
		number.rotation.x = -PI / 2
		number.position = POINTS[index] + Vector3(0, .025, 2.5)
		details.add_child(number)


func _atmosphere():
	var game = get_parent()
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", .18)
