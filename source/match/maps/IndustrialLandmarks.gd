extends RefCounted

const OBSTACLE = preload("res://source/match/units/traits/MovementObstacle.tscn")


static func place(parent, point, asset, radius = 8.0, model_scale = 1.0):
	var body = Node3D.new()
	body.name = asset
	body.position = point
	parent.add_child(body)
	var model = load("res://assets/models/environment/industrial/%s.glb" % asset).instantiate()
	model.scale = Vector3.ONE * model_scale
	body.add_child(model)
	var obstacle = OBSTACLE.instantiate()
	obstacle.name = "MovementObstacle"
	obstacle.radius = radius
	obstacle.sight_height = 6.9 * model_scale
	obstacle.affect_navigation_mesh = true
	body.add_child(obstacle)
	return body


static func flight_height(obstacles, point, baseline):
	var height = baseline
	for body in obstacles:
		var obstacle = body.get_node("MovementObstacle")
		var distance = Vector2(point.x - body.position.x, point.z - body.position.z).length()
		var rise = 1.0 - smoothstep(obstacle.radius + 1.9, obstacle.radius + 10.4, distance)
		height = maxf(height, lerpf(baseline, obstacle.sight_height + 1.1, rise))
	return height
