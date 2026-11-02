extends MeshInstance3D

## Small depth-tested ribbons sampled on the gameplay surface, including ramps.
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


func ring(center: Vector3, radius: float, width: float, color: Color):
	for index in 48:
		var a = TAU * index / 48.0
		var b = TAU * (index + 1) / 48.0
		_quad(
			center + Vector3(cos(a), 0, sin(a)) * (radius - width * .5),
			center + Vector3(cos(a), 0, sin(a)) * (radius + width * .5),
			center + Vector3(cos(b), 0, sin(b)) * (radius + width * .5),
			center + Vector3(cos(b), 0, sin(b)) * (radius - width * .5),
			color
		)


func line(start: Vector3, end: Vector3, width: float, color: Color):
	var direction = (end - start) * Vector3(1, 0, 1)
	if direction.is_zero_approx():
		return
	var side = Vector3(-direction.z, 0, direction.x).normalized() * width * .5
	var steps = maxi(1, ceili(direction.length() / .5))
	for index in steps:
		var a = start.lerp(end, float(index) / steps)
		var b = start.lerp(end, float(index + 1) / steps)
		_quad(a - side, a + side, b + side, b - side, color)


func slot(center: Vector3, heading: Vector3, color: Color):
	var side = Vector3(-heading.z, 0, heading.x) * .22
	for point in [
		center + heading * .38, center - heading * .16 + side, center - heading * .16 - side
	]:
		_vertex(point, color)


func arrow(start: Vector3, heading: Vector3, length: float, color: Color):
	var tip = start + heading * length
	var side = Vector3(-heading.z, 0, heading.x)
	line(start, tip, .09, color)
	line(tip, tip - heading * .65 + side * .45, .12, color)
	line(tip, tip - heading * .65 - side * .45, .12, color)


func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color):
	for point in [a, b, c, a, c, d]:
		_vertex(point, color)


func _vertex(point: Vector3, color: Color):
	if is_instance_valid(map):
		point.y = map.height_at(Vector2(point.x, point.z))
	point.y += .075
	_surface.surface_set_color(color)
	_surface.surface_add_vertex(to_local(point) if is_inside_tree() else point)
	_vertices += 1
