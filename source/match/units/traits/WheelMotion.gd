extends RefCounted

# Articulation only: use the rigid unit root so recoil, idle sway and suspension
# bob never create wheel travel. The authored axle is local +X, forward is -Z.
var wheels = []
var _unit
var _previous = Transform3D.IDENTITY


func setup(unit):
	_unit = unit
	_previous = unit.global_transform
	for pivot in unit.find_children("*WheelPivot*", "Node3D", true, false):
		var radius = 0.0
		for mesh in pivot.find_children("*", "MeshInstance3D", true, false):
			var relative = pivot.global_transform.affine_inverse() * mesh.global_transform
			for surface in mesh.mesh.get_surface_count():
				for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var point = relative * vertex
					var radial = pivot.global_basis * Vector3(0, point.y, point.z)
					radius = maxf(radius, radial.length())
		if radius > .001:
			wheels.append(
				{
					"pivot": pivot,
					"rest": pivot.basis,
					"offset": unit.to_local(pivot.global_position),
					"radius": radius,
					"angle": 0.0
				}
			)


func advance(delta):
	var current = _unit.global_transform
	var previous = _previous
	_previous = current
	# Spawns, restores and editor/test relocations must not spin through a jump.
	if current.origin.distance_to(previous.origin) > maxf(1.0, _unit.movement_speed * delta * 4.0):
		return
	var old_facing = previous.basis.z.normalized()
	var new_facing = current.basis.z.normalized()
	var forward = -(old_facing + new_facing).normalized()
	if forward.is_zero_approx():
		forward = -new_facing
	var turn = atan2(old_facing.cross(new_facing).y, old_facing.dot(new_facing))
	var translation = (current.origin - previous.origin).dot(forward)
	if absf(translation) < 0.0001 and absf(turn) < 0.0001:
		return
	for wheel in wheels:
		# Signed arc length also handles a pivot turn with no root translation.
		var travel = translation + turn * wheel.offset.x
		wheel.angle = wrapf(wheel.angle - travel / wheel.radius, -PI, PI)
		wheel.pivot.basis = wheel.rest * Basis(Vector3.RIGHT, wheel.angle)
