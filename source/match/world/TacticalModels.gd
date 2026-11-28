extends RefCounted

## Small, merged presentation meshes for transient supplies and transports.
## All coordinates are visual only; target bounds belong to the caller.
const STEEL = Color("5a6668")
const DARK = Color("29363b")
const EDGE = Color("a1aaa5")


static func aircraft(parent: Node3D, accent: Color, carrier := false):
	var surface = _surface()
	var hull = Color("858778") if carrier else Color("84918b")
	var trim = accent.lerp(Color("b5ae8d"), .68)
	_loft(
		surface,
		[
			Vector4(-3.05, .06, .08, -.04),
			Vector4(-2.65, .43, .33, 0),
			Vector4(-1.65, .68, .53, 0),
			Vector4(.85, .70, .56, 0),
			Vector4(1.85, .48, .43, .10),
			Vector4(2.85, .13, .18, .27),
		],
		hull
	)
	_loft(
		surface,
		[
			Vector4(-2.48, .16, .08, .29),
			Vector4(-1.92, .43, .21, .43),
			Vector4(-1.24, .41, .12, .47),
		],
		Color("304b53")
	)
	for side in [-1, 1]:
		_wing(surface, side, .12, [-.72, -.20, .50, .72], [.50, 3.45, 3.22, .58], hull)
		_wing(surface, side, .18, [.12, .19, .49, .49], [2.45, 3.40, 3.23, 2.45], trim)
		_wing(surface, side, .38, [1.75, 2.13, 2.71, 2.59], [.19, 1.58, 1.43, .19], hull)
		var engine = Vector3(side * 1.75, -.24, -.10)
		_tube(surface, engine + Vector3(0, 0, -.88), engine + Vector3(0, 0, .72), .34, STEEL)
		_tube(surface, engine + Vector3(0, 0, -.94), engine + Vector3(0, 0, -.87), .29, DARK)
		_tube(surface, engine + Vector3(0, 0, -.97), engine + Vector3(0, 0, -.94), .13, EDGE)
		_tube(surface, engine + Vector3(0, 0, .72), engine + Vector3(0, 0, .85), .27, DARK)
		_box(surface, Vector3(side * 1.75, .02, -.05), Vector3(.18, .35, .76), hull)
		_box(surface, Vector3(side * .57, -.07, .90), Vector3(.08, .38, .92), STEEL)
	_prism(
		surface,
		[
			Vector3(-.08, .28, 1.45),
			Vector3(-.08, 1.56, 2.08),
			Vector3(-.08, 1.58, 2.60),
			Vector3(-.08, .29, 2.79),
		],
		Vector3(.16, 0, 0),
		hull
	)
	_box(surface, Vector3(0, 1.10, 2.44), Vector3(.18, .18, .44), trim)
	for line in [-.72, .22, 1.05]:
		_box(surface, Vector3(0, .535, line), Vector3(.62, .024, .035), STEEL)
	_box(surface, Vector3(0, .57, -.15), Vector3(.28, .04, .88), trim)
	if carrier:
		_bevel_box(surface, Vector3(0, -.51, .35), Vector3(.97, .56, 1.62), Color("736d53"))
		for line in [-.20, .91]:
			_box(surface, Vector3(0, -.50, line), Vector3(1.02, .62, .09), DARK)
	_commit(parent, surface, "TransportMesh", Vector3.ONE * (.84 if carrier else 1.0))


static func cargo(parent: Node3D, accent: Color, repair := false):
	var surface = _surface()
	var body = Color("5b6868") if repair else Color("747967")
	var trim = accent.lerp(Color("bdab75"), .65)
	_bevel_box(surface, Vector3(0, .46, 0), Vector3(1.30, .84, 1.04), body)
	_bevel_box(surface, Vector3(0, .89, 0), Vector3(1.34, .16, 1.08), STEEL)
	_box(surface, Vector3(0, .12, 0), Vector3(1.36, .14, 1.10), DARK)
	for side in [-1, 1]:
		_box(surface, Vector3(side * .42, .54, 0), Vector3(.10, .92, 1.10), trim)
		_box(surface, Vector3(side * .42, .50, -.568), Vector3(.17, .20, .06), EDGE)
		_box(surface, Vector3(side * .42, .52, -.606), Vector3(.07, .09, .025), DARK)
		_box(surface, Vector3(side * .68, .46, 0), Vector3(.04, .13, .42), DARK)
		_box(surface, Vector3(side * .70, .47, 0), Vector3(.035, .07, .26), EDGE)
		_box(surface, Vector3(side * .47, .04, 0), Vector3(.22, .12, 1.00), STEEL)
	_box(surface, Vector3(0, .57, -.54), Vector3(.40, .24, .03), Color("b9b79f"))
	for stripe in 3:
		_box(surface, Vector3(-.11 + stripe * .11, .58, -.562), Vector3(.045, .12, .01), DARK)
	if repair:
		_box(surface, Vector3(0, .982, 0), Vector3(.58, .025, .19), Color("a4d7b8"))
		_box(surface, Vector3(0, .984, 0), Vector3(.19, .025, .58), Color("a4d7b8"))
	else:
		_box(surface, Vector3(0, .982, 0), Vector3(.43, .025, .38), trim)
		_box(surface, Vector3(0, .998, 0), Vector3(.20, .012, .16), STEEL)
	_commit(parent, surface, "SupplyMesh")


static func refined_core(parent: Node3D):
	var surface = _surface()
	_box(surface, Vector3(0, .14, 0), Vector3(.88, .18, .88), DARK)
	_bevel_box(surface, Vector3(0, .48, 0), Vector3(.72, .56, .72), STEEL)
	_bevel_box(surface, Vector3(0, .52, 0), Vector3(.48, .44, .48), Color("5ce1ff"))
	_box(surface, Vector3(0, .82, 0), Vector3(.64, .12, .64), Color("e2b857"))
	_commit(parent, surface, "RefinedCoreMesh")


static func radar(parent: Node3D):
	var surface = _surface()
	_bevel_box(surface, Vector3(0, .35, 0), Vector3(1.12, .64, .90), STEEL)
	_box(surface, Vector3(0, .69, -.06), Vector3(.70, .05, .48), Color("8d9a91"))
	_box(surface, Vector3(0, .73, -.11), Vector3(.46, .04, .28), Color("4b877f"))
	_tube(surface, Vector3(0, .61, .21), Vector3(0, 2.02, .21), .09, EDGE)
	for side in [-1, 1]:
		_tube(surface, Vector3(0, 1.03, .20), Vector3(side * .69, .03, .52), .045, STEEL)
		_box(surface, Vector3(side * .66, .04, .49), Vector3(.27, .07, .38), DARK)
	var center = Vector3(0, 2.0, .21)
	var forward = Vector3(0, .42, .91).normalized()
	var up = (Vector3.UP - forward * forward.dot(Vector3.UP)).normalized()
	for segment in 16:
		var angle_a = TAU * segment / 16.0
		var angle_b = TAU * (segment + 1) / 16.0
		var edge_a = center + (Vector3.RIGHT * cos(angle_a) + up * sin(angle_a)) * .77
		var edge_b = center + (Vector3.RIGHT * cos(angle_b) + up * sin(angle_b)) * .77
		_triangle(surface, center - forward * .18, edge_a, edge_b, Color("a4aea4"))
		_tube(surface, edge_a, edge_b, .025, EDGE)
	for side in [-1, 1]:
		_tube(surface, center + Vector3(side * .62, 0, 0), center + forward * .48, .025, STEEL)
	_tube(surface, center + forward * .42, center + forward * .57, .09, DARK)
	_box(surface, Vector3(.32, .76, -.10), Vector3(.05, .07, .05), Color("b9d5ad"))
	_commit(parent, surface, "RadarMesh")


static func _surface():
	var result = SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	return result


static func _commit(parent, surface, label, scale = Vector3.ONE):
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = surface.commit()
	node.scale = scale
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .76
	material.metallic = .20
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	parent.add_child(node)


static func _triangle(surface, a, b, c, color):
	var normal = (b - a).cross(c - a).normalized()
	var shade = color.darkened(.055 if normal.y < -.2 else 0.0)
	surface.set_normal(normal)
	surface.set_color(shade)
	# Godot front faces use clockwise winding; preserve the outward normal.
	for point in [a, c, b]:
		surface.add_vertex(point)


static func _face(surface, points, center, color):
	var normal = (points[1] - points[0]).cross(points[2] - points[0])
	if normal.dot(points[0] - center) < 0:
		points.reverse()
	for index in range(1, points.size() - 1):
		_triangle(surface, points[0], points[index], points[index + 1], color)


static func _prism(surface, polygon, offset, color):
	var center = Vector3.ZERO
	for point in polygon:
		center += point
	center = center / polygon.size() + offset * .5
	var end = polygon.map(func(point): return point + offset)
	_face(surface, polygon.duplicate(), center, color)
	_face(surface, end.duplicate(), center, color)
	for index in polygon.size():
		var next = (index + 1) % polygon.size()
		_face(surface, [polygon[index], polygon[next], end[next], end[index]], center, color)


static func _box(surface, point, size, color):
	var low = point - size * .5
	_prism(
		surface,
		[
			low,
			low + Vector3(size.x, 0, 0),
			low + Vector3(size.x, 0, size.z),
			low + Vector3(0, 0, size.z)
		],
		Vector3(0, size.y, 0),
		color
	)


static func _bevel_box(surface, point, size, color):
	var x = size.x * .5
	var z = size.z * .5
	var b = minf(x, z) * .17
	var polygon = []
	for corner in [
		Vector2(-x + b, -z),
		Vector2(x - b, -z),
		Vector2(x, -z + b),
		Vector2(x, z - b),
		Vector2(x - b, z),
		Vector2(-x + b, z),
		Vector2(-x, z - b),
		Vector2(-x, -z + b)
	]:
		polygon.append(point + Vector3(corner.x, -size.y * .5, corner.y))
	_prism(surface, polygon, Vector3(0, size.y, 0), color)


static func _wing(surface, side, height, zs, xs, color):
	var polygon = []
	for index in xs.size():
		polygon.append(Vector3(side * xs[index], height, zs[index]))
	_prism(surface, polygon, Vector3(0, .10, 0), color)


static func _loft(surface, sections, color):
	var rings = []
	var center = Vector3.ZERO
	for section in sections:
		var ring = []
		center += Vector3(0, section.w, section.x)
		for side in 12:
			var angle = TAU * side / 12.0
			ring.append(
				Vector3(cos(angle) * section.y, sin(angle) * section.z + section.w, section.x)
			)
		rings.append(ring)
	center /= sections.size()
	_face(surface, rings.front().duplicate(), center, color)
	_face(surface, rings.back().duplicate(), center, color)
	for index in range(1, rings.size()):
		for side in 12:
			var next = (side + 1) % 12
			_face(
				surface,
				[
					rings[index - 1][side],
					rings[index - 1][next],
					rings[index][next],
					rings[index][side]
				],
				center,
				color
			)


static func _tube(surface, start, end, radius, color):
	var direction = (end - start).normalized()
	var axis = Vector3.UP if absf(direction.y) < .9 else Vector3.RIGHT
	var right = direction.cross(axis).normalized() * radius
	var up = direction.cross(right).normalized() * radius
	var polygon = []
	for side in 10:
		var angle = TAU * side / 10.0
		polygon.append(start + right * cos(angle) + up * sin(angle))
	_prism(surface, polygon, end - start, color)
