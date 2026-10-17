extends "res://source/match/Map.gd"

const OBSTACLE = preload("res://source/match/units/traits/MovementObstacle.tscn")
const DEPLOYMENT = Vector3(76, 0, 66)
const TARGET = Vector3(156, 0, 65)
const NORTH = Vector3(116, 0, 22)
const SOUTH = Vector3(116, 0, 114)
const ENTRIES = [Vector3(169, 0, 113), Vector3(169, 0, 19)]
var exterior
var relay
var alternate_route = false
var flight_obstacles = []
var road_segments = PackedVector4Array()


func _ready():
	var game = get_parent()
	if not game.restoring:
		var progress = load("res://source/match/campaign/CampaignProgress.gd").new()
		progress.read_progress(game.progress_path)
		game.alternate_route = progress.foundry_complete
	alternate_route = game.alternate_route
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", .22)
	_road(Vector3(-46, 0, 66), DEPLOYMENT)
	_road(DEPLOYMENT, Vector3(92, 0, 114))
	_road(Vector3(92, 0, 114), Vector3(145, 0, 114))
	_road(Vector3(145, 0, 114), TARGET)
	_road(DEPLOYMENT, Vector3(92, 0, 22))
	_road(Vector3(92, 0, 22), Vector3(146, 0, 22))
	_road(Vector3(146, 0, 22), TARGET)
	_road(TARGET, Vector3(230, 0, 65))
	$Geometry/Terrain.mesh.material = $Geometry/Terrain.mesh.material.duplicate()
	$Geometry/Terrain.mesh.material.set_shader_parameter("roads", road_segments)
	exterior = load("res://source/match/maps/HorizonBackdrop.gd").new()
	exterior.ground_material = $Geometry/Terrain.mesh.material
	add_child(exterior)
	_ground_cover()
	# A continuous high berm reaches the north boundary. The reward cuts a real passage.
	for z in range(0, 100, 9):
		if alternate_route and z in [18, 27]:
			continue
		_landmark(Vector3(116, 0, z), "CutBerm%d" % (1 + (z / 9) % 3))
	_landmark(Vector3(52, 0, 44), "ServiceRuin")
	_landmark(Vector3(52, 0, 91), "PumpStation")
	_landmark(Vector3(88, 0, 92), "RelaySubstation")
	relay = load("res://source/match/objectives/DeploymentControl.gd").new()
	relay.position = DEPLOYMENT
	add_child(relay)
	for point in [Vector3(10, 0, 89), Vector3(82, 0, 78), Vector3(164, 0, 25)]:
		for offset in [
			Vector2(-3, 0), Vector2.ZERO, Vector2(3, 0), Vector2(-1.5, -3), Vector2(1.5, -3)
		]:
			var resource = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			resource.resource_a = 600
			resource.position = point + Vector3(offset.x, 0, offset.y)
			$Resources.add_child(resource)
		for extra in 2:
			var electronics = (
				load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
			)
			electronics.resource_b = 600
			electronics.position = point + Vector3(0, 0, 5)
			electronics.position += Vector3(3, 0, 0) * extra
			$Resources.add_child(electronics)


func _landmark(point, asset):
	var shelf = Node3D.new()
	shelf.name = asset
	shelf.set_meta("neutral_asset", asset)
	shelf.position = point
	$Decorations.add_child(shelf)
	var model = load("res://assets/models/environment/%s.glb" % asset).instantiate()
	shelf.add_child(model)
	load("res://source/match/maps/IndustrialMaterials.gd").weather(model)
	var obstacle = OBSTACLE.instantiate()
	obstacle.radius = 5.6
	obstacle.sight_height = 7.0
	obstacle.affect_navigation_mesh = true
	shelf.add_child(obstacle)
	flight_obstacles.append(shelf)


func flight_height_at(point, baseline):
	# Begin climbing before the obstruction, with clearance for the full airframe.
	# Actual unit height is used by sight, projectile origins and selection.
	var height = baseline
	for obstacle in flight_obstacles:
		var distance = (
			Vector2(point.x - obstacle.position.x, point.z - obstacle.position.z).length()
		)
		var rise = 1.0 - smoothstep(7.5, 16.0, distance)
		height = maxf(height, lerpf(baseline, 8.0, rise))
	return height


func _road(a, b):
	road_segments.append(Vector4(a.x, a.z, b.x, b.z))


func _ground_cover():
	var cover = Node3D.new()
	cover.name = "HorizonGroundCover"
	add_child(cover)
	for point in [
		Vector2(36, 18),
		Vector2(62, 32),
		Vector2(47, 110),
		Vector2(69, 108),
		Vector2(89, 51),
		Vector2(137, 75),
		Vector2(162, 109),
		Vector2(175, 29)
	]:
		var model = load("res://source/match/maps/Vegetation.gd").bush(cover.get_child_count())
		model.position = Vector3(point.x, .01, point.y)
		model.rotation.y = point.x * .13
		cover.add_child(model)
