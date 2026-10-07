extends "res://source/match/maps/AlpineRelay.gd"

const POINTS = [Vector2(46, 23), Vector2(70, 44), Vector2(46, 65)]
const NAMES = ["North", "East", "South"]
const SHELVES = [Vector2(46, 44), Vector2(69, 19), Vector2(69, 69)]
const ACCESS_ROADS = [
	Vector4(18, 44, 46, 23),
	Vector4(18, 44, 46, 65),
	Vector4(46, 23, 70, 44),
	Vector4(46, 65, 70, 44),
	Vector4(70, 44, 94, 15),
	Vector4(70, 44, 94, 73),
	Vector4(18, 44, 10, 59),
	Vector4(29, 13, 36, 30),
	Vector4(29, 75, 36, 58),
	Vector4(70, 44, 94, 44)
]
const DEPOSITS = [Vector2(10, 59), Vector2(29, 13), Vector2(29, 75)]


func overview():
	return {
		"ridges": SHELVES,
		"radius": RIDGE_RADIUS,
		"fields": DEPOSITS,
		"relays": POINTS,
		"roads": ACCESS_ROADS,
		"road_width": 6.5
	}


func _ready():
	_configure_atmosphere()
	var material = $Geometry/Terrain.mesh.material.duplicate()
	var roads = PackedVector4Array(ACCESS_ROADS)
	roads.resize(16)
	material.set_shader_parameter("roads", roads)
	material.set_shader_parameter("road_count", ACCESS_ROADS.size())
	material.set_shader_parameter("relays", PackedVector2Array(POINTS))
	$Geometry/Terrain.mesh.material = material
	exterior = load("res://source/match/maps/SplitBackdrop.gd").new()
	add_child(exterior)
	_split_ground_cover()
	for index in SHELVES.size():
		_ridge(SHELVES[index], index)
	for index in POINTS.size():
		var relay = load("res://source/match/objectives/CaptureRelay.gd").new()
		relay.name = NAMES[index] + "Relay"
		relay.position = Vector3(POINTS[index].x, 0, POINTS[index].y)
		add_child(relay)
		relays.append(relay)
	for point in DEPOSITS:
		for offset in [-2.5, 0.0, 2.5]:
			var resource = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			resource.resource_a = 200
			resource.position = Vector3(point.x + offset, 0, point.y)
			$Resources.add_child(resource)
		var electronics = load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
		electronics.resource_b = 180
		electronics.position = Vector3(point.x + 5, 0, point.y + 2)
		$Resources.add_child(electronics)


func _split_ground_cover():
	var cover = Node3D.new()
	cover.name = "SplitGroundCover"
	add_child(cover)
	for point in [
		Vector2(8, 12),
		Vector2(16, 20),
		Vector2(34, 8),
		Vector2(52, 9),
		Vector2(82, 9),
		Vector2(100, 28),
		Vector2(100, 60),
		Vector2(84, 79),
		Vector2(52, 79),
		Vector2(34, 83),
		Vector2(18, 74),
		Vector2(8, 80)
	]:
		var model = load("res://assets/models/environment/alpine/WinterSedge.glb").instantiate()
		model.position = Vector3(point.x, .006, point.y)
		model.rotation.y = point.x * .31
		cover.add_child(model)
