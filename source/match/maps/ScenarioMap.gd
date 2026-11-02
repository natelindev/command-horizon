extends "res://source/match/Map.gd"

const Document = preload("res://source/scenario/ScenarioDocument.gd")
var scenario: Dictionary = {}
var points_of_interest := []


func _enter_tree():
	assert(Document.new().validate(scenario), "ScenarioMap requires a validated document")
	size = Vector2(scenario.size[0], scenario.size[1])
	_build()
	super()


func _build():
	var terrain = get_node("Geometry/Terrain")
	terrain.mesh = terrain.mesh.duplicate()
	terrain.mesh.material = terrain.mesh.material.duplicate()
	var colors = {
		"desert": [Color("8f7653"), Color("baa47e")],
		"temperate": [Color("40523a"), Color("83916c")],
		"volcanic": [Color("393639"), Color("706765")]
	}[scenario.biome]
	terrain.mesh.material.set_shader_parameter("low", colors[0])
	terrain.mesh.material.set_shader_parameter("high", colors[1])
	for entry in scenario.spawns:
		var marker := Marker3D.new()
		marker.position = Vector3(entry.x, 0, entry.z)
		marker.rotation.y = deg_to_rad(entry.yaw)
		get_node("SpawnPoints").add_child(marker)
	for entry in scenario.items:
		if entry.kind in ["materials", "electronics"]:
			var deposit = (
				load(
					(
						"res://source/match/units/non-player/%s.tscn"
						% ("ResourceA" if entry.kind == "materials" else "ResourceB")
					)
				)
				. instantiate()
			)
			deposit.position = Vector3(entry.x, 0, entry.z)
			deposit.rotation.y = deg_to_rad(entry.yaw)
			deposit.set(
				"resource_a" if entry.kind == "materials" else "resource_b", int(entry.amount)
			)
			get_node("Resources").add_child(deposit)
		elif entry.kind in Document.KITS:
			var kit = Document.KITS[entry.kind]
			var body := Node3D.new()
			body.position = Vector3(entry.x, 0, entry.z)
			body.rotation.y = deg_to_rad(entry.yaw)
			get_node("Decorations").add_child(body)
			var model = load("res://assets/models/environment/%s.glb" % kit.model).instantiate()
			model.scale = Vector3.ONE * kit.scale
			body.add_child(model)
			var obstacle = (
				load("res://source/match/units/traits/MovementObstacle.tscn").instantiate()
			)
			obstacle.radius = kit.radius
			obstacle.sight_height = kit.height
			obstacle.affect_navigation_mesh = true
			body.add_child(obstacle)
			interior_obstacles.append(body)


func overview() -> Dictionary:
	return {
		"ridges": [],
		"radius": 0,
		"fields":
		(
			scenario
			. items
			. filter(func(item): return item.kind in ["materials", "electronics"])
			. map(func(item): return Vector2(item.x, item.z))
		),
		"relays": [],
		"roads": [],
		"points_of_interest": Document.site_definitions(scenario)
	}
