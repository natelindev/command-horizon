extends MeshInstance3D

## Depth-tested world-space tactical ribbons and holographic accents sampled on terrain.
const Cache = preload("res://source/utils/RuntimeCache.gd")
var map
var _surface = ImmediateMesh.new()
var _material: StandardMaterial3D
var _vertices = 0


func _init():
	# Keep the first actually drawn generated shader alive after Loading frees
	# its disposable ring. Later markers still own independently fading copies.
	var materials = Cache.bucket("terrain_feedback")
	if materials.has("prototype"):
		_material = materials.prototype.duplicate()
	else:
		_material = StandardMaterial3D.new()
		materials.prototype = _material
	_material.albedo_color = Color.WHITE
	mesh = _surface
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.render_priority = 10
	material_override = _material


func begin():
	_surface.clear_surfaces()
	_surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_vertices = 0


func finish():
	if _vertices == 0:
		# ImmediateMesh requires at least one primitive per surface.
		for index in 3:
			_vertex(Vector3.ZERO, Color.TRANSPARENT)
	_surface.surface_end()


func fade(alpha: float):
	_material.albedo_color.a = clampf(alpha, 0.0, 1.0)


func ring(
	center: Vector3,
	radius: float,
	width: float,
	color: Color,
	segments: int = 48,
	lift: float = 0.0
):
	polygon_ring(center, radius, width, segments, 0.0, color, lift)


func polygon_ring(
	center: Vector3,
	radius: float,
	width: float,
	sides: int,
	rotation: float,
	color: Color,
	lift: float = 0.0
):
	var inner = maxf(0.01, radius - width * .5)
	var outer = radius + width * .5
	for index in sides:
		var a = rotation + TAU * index / float(sides)
		var b = rotation + TAU * (index + 1) / float(sides)
		var dir_a = Vector3(cos(a), 0, sin(a))
		var dir_b = Vector3(cos(b), 0, sin(b))
		_quad(
			center + dir_a * inner,
			center + dir_a * outer,
			center + dir_b * outer,
			center + dir_b * inner,
			color,
			lift
		)


func arc(
	center: Vector3,
	radius: float,
	width: float,
	start_angle: float,
	end_angle: float,
	color: Color,
	segments: int = 16,
	lift: float = 0.0
):
	var inner = maxf(0.01, radius - width * .5)
	var outer = radius + width * .5
	var count = maxi(1, segments)
	for index in count:
		var t0 = float(index) / count
		var t1 = float(index + 1) / count
		var a = lerpf(start_angle, end_angle, t0)
		var b = lerpf(start_angle, end_angle, t1)
		var dir_a = Vector3(cos(a), 0, sin(a))
		var dir_b = Vector3(cos(b), 0, sin(b))
		_quad(
			center + dir_a * inner,
			center + dir_a * outer,
			center + dir_b * outer,
			center + dir_b * inner,
			color,
			lift
		)


func filled_polygon(
	center: Vector3, radius: float, sides: int, rotation: float, color: Color, lift: float = 0.0
):
	for index in sides:
		var a = rotation + TAU * index / float(sides)
		var b = rotation + TAU * (index + 1) / float(sides)
		_vertex_lifted(center, color, lift)
		_vertex_lifted(center + Vector3(cos(a), 0, sin(a)) * radius, color, lift)
		_vertex_lifted(center + Vector3(cos(b), 0, sin(b)) * radius, color, lift)


func line(start: Vector3, end: Vector3, width: float, color: Color, lift: float = 0.0):
	var direction = (end - start) * Vector3(1, 0, 1)
	if direction.is_zero_approx():
		return
	var side = Vector3(-direction.z, 0, direction.x).normalized() * width * .5
	var steps = maxi(1, ceili(direction.length() / .5))
	for index in steps:
		var a = start.lerp(end, float(index) / steps)
		var b = start.lerp(end, float(index + 1) / steps)
		_quad(a - side, a + side, b + side, b - side, color, lift)


func chevron(
	center: Vector3, heading: Vector3, size: float, width: float, color: Color, lift: float = 0.0
):
	var fwd = (heading * Vector3(1, 0, 1)).normalized()
	if fwd.is_zero_approx():
		fwd = Vector3.FORWARD
	var side = Vector3(-fwd.z, 0, fwd.x)
	var tip = center + fwd * (size * 0.52)
	var left = center - fwd * (size * 0.42) + side * (size * 0.62)
	var right = center - fwd * (size * 0.42) - side * (size * 0.62)
	line(left, tip, width, color, lift)
	line(right, tip, width, color, lift)


func wedge_pip(
	center: Vector3,
	heading: Vector3,
	length: float,
	half_width: float,
	color: Color,
	lift: float = 0.0
):
	var fwd = (heading * Vector3(1, 0, 1)).normalized()
	if fwd.is_zero_approx():
		fwd = Vector3.FORWARD
	var side = Vector3(-fwd.z, 0, fwd.x) * half_width
	var tip = center + fwd * (length * 0.62)
	var tail_l = center - fwd * (length * 0.38) + side
	var tail_r = center - fwd * (length * 0.38) - side
	var notch = center - fwd * (length * 0.14)
	_vertex_lifted(tip, color, lift)
	_vertex_lifted(tail_l, color, lift)
	_vertex_lifted(notch, color, lift)
	_vertex_lifted(tip, color, lift)
	_vertex_lifted(notch, color, lift)
	_vertex_lifted(tail_r, color, lift)


func diamond_pip(
	center: Vector3,
	heading: Vector3,
	length: float,
	half_width: float,
	color: Color,
	lift: float = 0.0
):
	var fwd = (heading * Vector3(1, 0, 1)).normalized()
	if fwd.is_zero_approx():
		fwd = Vector3.FORWARD
	var side = Vector3(-fwd.z, 0, fwd.x) * half_width
	var front = center + fwd * (length * 0.58)
	var back = center - fwd * (length * 0.42)
	_vertex_lifted(front, color, lift)
	_vertex_lifted(center + side, color, lift)
	_vertex_lifted(center - side, color, lift)
	_vertex_lifted(back, color, lift)
	_vertex_lifted(center - side, color, lift)
	_vertex_lifted(center + side, color, lift)


func beacon_pillar(
	center: Vector3,
	bottom_radius: float,
	top_radius: float,
	height: float,
	bottom_color: Color,
	top_color: Color,
	sides: int = 6,
	rotation: float = 0.0
):
	var base_y = _ground_y(center) + 0.075
	for index in sides:
		var a = rotation + TAU * index / float(sides)
		var b = rotation + TAU * (index + 1) / float(sides)
		var dir_a = Vector3(cos(a), 0, sin(a))
		var dir_b = Vector3(cos(b), 0, sin(b))
		var b0 = Vector3(
			center.x + dir_a.x * bottom_radius, base_y, center.z + dir_a.z * bottom_radius
		)
		var b1 = Vector3(
			center.x + dir_b.x * bottom_radius, base_y, center.z + dir_b.z * bottom_radius
		)
		var t0 = Vector3(
			center.x + dir_a.x * top_radius, base_y + height, center.z + dir_a.z * top_radius
		)
		var t1 = Vector3(
			center.x + dir_b.x * top_radius, base_y + height, center.z + dir_b.z * top_radius
		)
		_vertex_raw(b0, bottom_color)
		_vertex_raw(b1, bottom_color)
		_vertex_raw(t1, top_color)
		_vertex_raw(b0, bottom_color)
		_vertex_raw(t1, top_color)
		_vertex_raw(t0, top_color)


func slot(center: Vector3, heading: Vector3, color: Color, faction: String = "bastion"):
	var dark = Color(0.05, 0.07, 0.09, color.a * 0.72)
	if faction == "helix":
		diamond_pip(center, heading, 0.72, 0.30, dark, 0.0)
		diamond_pip(center, heading, 0.56, 0.22, color, 0.015)
	elif faction == "frontier":
		wedge_pip(center, heading, 0.76, 0.34, dark, 0.0)
		wedge_pip(center, heading, 0.58, 0.25, color, 0.015)
	else:
		polygon_ring(center, 0.30, 0.09, 8, PI * 0.125, dark, 0.0)
		wedge_pip(center, heading, 0.64, 0.27, color, 0.015)


func arrow(
	start: Vector3, heading: Vector3, length: float, color: Color, faction: String = "bastion"
):
	var tip = start + heading * length
	var dark = Color(0.05, 0.07, 0.09, color.a * 0.70)
	if faction == "helix":
		line(start, tip - heading * 0.25, 0.16, dark, 0.0)
		line(start, tip - heading * 0.18, 0.08, color, 0.015)
		diamond_pip(tip - heading * 0.22, heading, 0.95, 0.38, dark, 0.005)
		diamond_pip(tip - heading * 0.22, heading, 0.76, 0.28, color, 0.02)
	elif faction == "frontier":
		line(start, tip - heading * 0.20, 0.22, dark, 0.0)
		line(start, tip - heading * 0.16, 0.11, color, 0.015)
		chevron(tip - heading * 0.28, heading, 0.92, 0.20, dark, 0.005)
		chevron(tip - heading * 0.28, heading, 0.88, 0.11, color, 0.02)
		chevron(tip - heading * 0.88, heading, 0.70, 0.09, Color(color, color.a * 0.78), 0.02)
	else:
		line(start, tip - heading * 0.18, 0.20, dark, 0.0)
		line(start, tip - heading * 0.14, 0.095, color, 0.015)
		chevron(tip - heading * 0.24, heading, 0.86, 0.19, dark, 0.005)
		chevron(tip - heading * 0.24, heading, 0.82, 0.105, color, 0.02)
		chevron(tip - heading * 0.74, heading, 0.64, 0.085, Color(color, color.a * 0.82), 0.02)


func _ground_y(point: Vector3) -> float:
	return map.height_at(Vector2(point.x, point.z)) if is_instance_valid(map) else point.y


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, lift: float = 0.0):
	for point in [a, b, c, a, c, d]:
		_vertex_lifted(point, color, lift)


func _vertex(point: Vector3, color: Color):
	_vertex_lifted(point, color, 0.0)


func _vertex_lifted(point: Vector3, color: Color, lift: float):
	point.y = _ground_y(point) + 0.075 + lift
	_vertex_raw(point, color)


func _vertex_raw(point: Vector3, color: Color):
	_surface.surface_set_color(color)
	_surface.surface_add_vertex(to_local(point) if is_inside_tree() else point)
	_vertices += 1
