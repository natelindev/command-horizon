extends "res://source/match/Map.gd"

const Landmarks = preload("res://source/match/maps/IndustrialLandmarks.gd")
const ASSETS = ["SawtoothWorkshop", "CoolingHall", "ServiceOffice", "DamagedWarehouse"]
const NODES = [Vector3(76, 0, 26), Vector3(76, 0, 90)]
const CONTROL = Vector3(124, 0, 58)
const ENTRY = Vector3(151, 0, 58)
const BLOCKS = [Vector3(55, 0, 43), Vector3(55, 0, 73), Vector3(96, 0, 43), Vector3(96, 0, 73)]
var relay
var exterior
var flight_obstacles = []
var road_segments = PackedVector4Array()


func _ready():
	var game = get_parent()
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", .22)
	for z in [26, 58, 90]:
		_road(Vector3(-46 if z == 58 else 32, 0, z), Vector3(206 if z == 58 else 145, 0, z))
	for x in [35, 76, 118, 145]:
		_road(Vector3(x, 0, -22 if x == 76 else 18), Vector3(x, 0, 138 if x == 145 else 98))
	for index in BLOCKS.size():
		flight_obstacles.append(Landmarks.place($Decorations, BLOCKS[index], ASSETS[index]))
	var material = $Geometry/Terrain.mesh.material.duplicate()
	road_segments.resize(8)
	material.set_shader_parameter("roads", road_segments)
	material.set_shader_parameter("road_count", 7)
	material.set_shader_parameter("road_half_width", 3.5)
	material.set_shader_parameter("pavement_center", Vector2(90, 58))
	material.set_shader_parameter("pavement_extent", Vector2(64, 44))
	$Geometry/Terrain.mesh.material = material
	exterior = load("res://source/match/maps/FoundryBackdrop.gd").new()
	exterior.ground_material = material
	add_child(exterior)
	_ground_cover()
	relay = load("res://source/match/objectives/FoundryControl.gd").new()
	relay.position = CONTROL
	add_child(relay)
	# Foundry furnaces surround an accessible control yard; they are solid scenery.
	for point in [Vector3(133, 0, 39), Vector3(133, 0, 77)]:
		flight_obstacles.append(Landmarks.place($Decorations, point, "FurnaceBlock", 5.0))
	for body in flight_obstacles:
		load("res://source/match/maps/IndustrialMaterials.gd").weather(body)
	for point in [Vector3(10, 0, 79), Vector3(43, 0, 105)]:
		for offset in [
			Vector2(-2.5, 0), Vector2.ZERO, Vector2(2.5, 0), Vector2(-1.5, -3), Vector2(1.5, -3)
		]:
			var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			deposit.resource_a = 480
			deposit.position = point + Vector3(offset.x, 0, offset.y)
			$Resources.add_child(deposit)
		for extra in 2:
			var electronics = (
				load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
			)
			electronics.resource_b = 480
			electronics.position = point + Vector3(0, 0, 5)
			electronics.position += Vector3(3, 0, 0) * extra
			$Resources.add_child(electronics)


func flight_height_at(point, baseline):
	return Landmarks.flight_height(flight_obstacles, point, baseline)


func _road(a, b):
	road_segments.append(Vector4(a.x, a.z, b.x, b.z))


func _ground_cover():
	var cover = Node3D.new()
	cover.name = "FoundryGroundCover"
	add_child(cover)
	for point in [
		Vector2(7, 14),
		Vector2(17, 23),
		Vector2(22, 94),
		Vector2(55, 109),
		Vector2(92, 108),
		Vector2(128, 108),
		Vector2(152, 14),
		Vector2(151, 104)
	]:
		var model = load("res://assets/models/environment/supply/RoadSage.glb").instantiate()
		model.position = Vector3(point.x, .006, point.y)
		model.rotation.y = point.x * .31
		cover.add_child(model)
