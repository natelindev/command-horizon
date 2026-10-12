extends "res://source/match/Map.gd"

const OBSTACLE = preload("res://source/match/units/traits/MovementObstacle.tscn")
const SITES = [Vector3(84, 0, 42), Vector3(100, 0, 62)]
const SITE_NAMES = ["North battery", "South battery"]
const LAUNCH = Vector3(20, 0, 52)
const EXIT = Vector3(132, 0, 52)
const SCREEN = Vector3(108, 0, 52)
const ENTRIES = [Vector3(123, 0, 88), Vector3(123, 0, 16)]
const KIT = "res://assets/models/environment/quarry/"
var flight_obstacles = []


func _ready():
	var material = $Geometry/Terrain.mesh.material.duplicate()
	material.set_shader_parameter(
		"roads",
		PackedVector4Array(
			[
				Vector4(28, 18, 119, 18),
				Vector4(28, 87, 119, 87),
				Vector4(28, 18, 28, 87),
				Vector4(119, 18, 119, 87)
			]
		)
	)
	material.set_shader_parameter(
		"pads", PackedVector2Array([Vector2(LAUNCH.x, LAUNCH.z), Vector2(EXIT.x, EXIT.z)])
	)
	material.set_shader_parameter(
		"sites",
		PackedVector2Array([Vector2(SITES[0].x, SITES[0].z), Vector2(SITES[1].x, SITES[1].z)])
	)
	$Geometry/Terrain.mesh.material = material
	var benches = ["QuarryBenchA", "QuarryBenchB", "QuarryBenchA", "QuarryBenchC", "QuarryBenchB"]
	for index in 5:
		_landmark(Vector3(66, 0, [29, 40, 51, 62, 73][index]), benches[index], 6.5)
	for z in [27, 35, 76, 84]:
		for x in [44, 49]:
			_landmark(Vector3(x, 0, z), "QuarryContainerA" if x == 44 else "QuarryContainerB", 3.0)
	add_child(load("res://source/match/maps/QuarryBackdrop.gd").new())
	_atmosphere()
	for point in [Vector3(9, 0, 72), Vector3(42, 0, 93), Vector3(133, 0, 85)]:
		for offset in [-2.5, 0.0, 2.5]:
			var deposit = load("res://source/match/units/non-player/ResourceA.tscn").instantiate()
			deposit.resource_a = 200
			deposit.position = point + Vector3(offset, 0, 0)
			$Resources.add_child(deposit)
		var electronics = load("res://source/match/units/non-player/ResourceB.tscn").instantiate()
		electronics.resource_b = 240
		electronics.position = point + Vector3(0, 0, 5)
		$Resources.add_child(electronics)


func _landmark(point, asset, radius):
	var body = Node3D.new()
	body.name = asset
	body.position = point
	var model = load(KIT + asset + ".glb").instantiate()
	load("res://source/match/maps/QuarryMaterials.gd").weather_stone(model)
	model.name = "Model"
	# Existing obstacle alignment puts its parent at 0.6 m; ground the model separately.
	model.position.y = -0.6
	body.add_child(model)
	var obstacle = OBSTACLE.instantiate()
	obstacle.radius = radius
	obstacle.affect_navigation_mesh = true
	body.add_child(obstacle)
	$Decorations.add_child(body)
	flight_obstacles.append(body)


func flight_height_at(point, baseline):
	return load("res://source/match/maps/IndustrialLandmarks.gd").flight_height(
		flight_obstacles, point, baseline
	)


func _atmosphere():
	var game = get_parent()
	game.get_node("Fog").hide()
	var world = game.get_node("WorldEnvironment")
	world.environment = world.environment.duplicate()
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("afbec2")
	world.environment.ambient_light_energy = .46
	world.environment.tonemap_exposure = .9
	var sun = game.get_node("DirectionalLight3D")
	sun.light_color = Color("f0e6cc")
	sun.light_energy = 1.15
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = .5
	var overlay = game.get_node("FogOfWar/ScreenOverlay")
	overlay.material_override = overlay.material_override.duplicate()
	overlay.material_override.set_shader_parameter("exterior_visibility", .2)
