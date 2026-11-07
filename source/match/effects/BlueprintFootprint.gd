extends "res://source/match/effects/TerrainFeedback.gd"

## The same circle/polygon used by placement, sampled onto terrain and ramps.
var outline = PackedVector2Array()
var radius = 1.0
var portal = Vector3.ZERO
var portal_direction = Vector3.FORWARD
var has_portal = false
var _last_pose = Transform3D(Basis.IDENTITY, Vector3.INF)
var _last_valid = false


func refresh(pose: Transform3D, valid: bool):
	if pose == _last_pose and valid == _last_valid:
		return
	_last_pose = pose
	_last_valid = valid
	var polygon = outline
	if polygon.is_empty():
		polygon = PackedVector2Array()
		for index in 64:
			polygon.append(Vector2.from_angle(index * TAU / 64.0) * radius)
	var color = Color(.74, .9, .87, .7) if valid else Color(1, .55, .38, .75)
	begin()
	var bounds = Rect2(polygon[0], Vector2.ZERO)
	for index in polygon.size():
		bounds = bounds.expand(polygon[index])
		line(
			_world(pose, polygon[index]),
			_world(pose, polygon[(index + 1) % polygon.size()]),
			.055,
			color
		)
	var grid_color = color
	grid_color.a = .16
	for x in range(ceili(bounds.position.x), floori(bounds.end.x) + 1):
		_grid_line(
			Vector2(x, bounds.position.y), Vector2(x, bounds.end.y), polygon, pose, grid_color
		)
	for z in range(ceili(bounds.position.y), floori(bounds.end.y) + 1):
		_grid_line(
			Vector2(bounds.position.x, z), Vector2(bounds.end.x, z), polygon, pose, grid_color
		)
	if has_portal:
		arrow(pose * portal, pose.basis * portal_direction, 2.0, color)
	finish()


func _grid_line(a: Vector2, b: Vector2, polygon, pose, color):
	var cuts = [a, b]
	for index in polygon.size():
		var point = Geometry2D.segment_intersects_segment(
			a, b, polygon[index], polygon[(index + 1) % polygon.size()]
		)
		if point != null:
			cuts.append(point)
	cuts.sort_custom(
		func(first, second): return a.distance_squared_to(first) < a.distance_squared_to(second)
	)
	for index in cuts.size() - 1:
		if Geometry2D.is_point_in_polygon((cuts[index] + cuts[index + 1]) * .5, polygon):
			line(_world(pose, cuts[index]), _world(pose, cuts[index + 1]), .025, color)


func _world(pose: Transform3D, point: Vector2) -> Vector3:
	return pose * Vector3(point.x, 0, point.y)
