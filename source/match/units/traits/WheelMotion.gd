extends RefCounted

# Articulation only: use the rigid unit root so recoil, idle sway and suspension
# bob never create wheel travel. Forward is -Z; each wheel spins about its axle,
# the pivot axis parallel to the unit's local X (authored wheels may be rotated).
var wheels := []
var _unit
var _previous := Transform3D.IDENTITY


func setup(unit):
	_unit = unit
	_previous = unit.global_transform
	var pivots = unit.find_children("*WheelPivot*", "Node3D", true, false)
	for pivot in unit.find_children("*_Wheel_*", "Node3D", true, false):
		if not pivot is MeshInstance3D and pivot not in pivots:
			pivots.append(pivot)
	for pivot in unit.find_children("*", "VehicleWheel3D", true, false):
		if pivot not in pivots:
			pivots.append(pivot)
	for pivot in pivots:
		var pivot_in_unit = _transform_to(pivot, unit)
		var axle = (pivot_in_unit.basis.inverse() * Vector3.RIGHT).normalized()
		var radius = 0.0
		for mesh in pivot.find_children("*", "MeshInstance3D", true, false):
			var relative = pivot_in_unit.affine_inverse() * _transform_to(mesh, unit)
			for surface in mesh.mesh.get_surface_count():
				for vertex in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var point = relative * vertex
					var radial = pivot_in_unit.basis * (point - axle * point.dot(axle))
					radius = maxf(radius, radial.length())
		if radius > .001:
			wheels.append(
				{
					"pivot": pivot,
					"rest": pivot.basis,
					"axle": axle,
					"offset": pivot_in_unit.origin,
					"radius": radius,
					"angle": 0.0
				}
			)


static func _transform_to(node, ancestor):
	# Works before the unit enters the scene tree (production proxies).
	var result = Transform3D.IDENTITY
	var current = node
	while current != null and current != ancestor:
		if current is Node3D:
			result = current.transform * result
		current = current.get_parent()
	return result


func advance(delta: float):
	var current: Transform3D = _unit.global_transform
	var previous: Transform3D = _previous
	_previous = current
	# Spawns, restores and editor/test relocations must not spin through a jump.
	var distance := current.origin.distance_to(previous.origin)
	# Keep the exact distance/threshold comparison, querying live speed only
	# when the one-metre minimum could actually classify this as a teleport.
	if distance > 1.0 and distance > maxf(1.0, _unit.movement_speed * delta * 4.0):
		return
	var old_facing: Vector3 = previous.basis.z.normalized()
	var new_facing: Vector3 = current.basis.z.normalized()
	var forward: Vector3 = -(old_facing + new_facing).normalized()
	if forward.is_zero_approx():
		forward = -new_facing
	var turn: float = atan2(old_facing.cross(new_facing).y, old_facing.dot(new_facing))
	var translation: float = (current.origin - previous.origin).dot(forward)
	if absf(translation) < 0.0001 and absf(turn) < 0.0001:
		return
	for wheel in wheels:
		# Signed arc length also handles a pivot turn with no root translation.
		var travel: float = translation + turn * wheel.offset.x
		wheel.angle = wrapf(wheel.angle - travel / wheel.radius, -PI, PI)
		wheel.pivot.basis = wheel.rest * Basis(wheel.axle, wheel.angle)
