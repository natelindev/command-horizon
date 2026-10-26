extends RefCounted


## Pure transform stand-ins let the existing gait and IK solver run without
## touching scene nodes. Only this coordinator retains the main-thread bindings.
class PoseTransform:
	extends RefCounted
	var transform := Transform3D.IDENTITY
	var position: Vector3:
		get:
			return transform.origin
		set(value):
			transform.origin = value
	var basis: Basis:
		get:
			return transform.basis
		set(value):
			transform.basis = value
	var rotation: Vector3:
		get:
			# Match Node3D's rotation/scale decomposition. Reading Euler angles
			# directly from a scaled basis corrupts component writes such as +=.
			var normalized = transform.basis.orthonormalized()
			if normalized.determinant() < 0.0:
				normalized = normalized.scaled(Vector3(-1, -1, -1))
			return normalized.get_euler()
		set(value):
			transform.basis = Basis.from_euler(value).scaled_local(transform.basis.get_scale())
	var scale: Vector3:
		get:
			return transform.basis.get_scale()


class Job:
	extends RefCounted
	var motion: RefCounted
	var pending := false
	var delta := 0.0
	var distance := 0.0
	var clock := 0.0
	var gesture := 0.0
	var recoil := 0.0
	var aiming := 0.0
	var native_solved := false
	var native_parts: Array = []
	var native_config := PackedFloat64Array()

	func configure(dt: float, travel: float, time: float, idle: float, kick: float, aim: float):
		delta = dt
		distance = travel
		clock = time
		gesture = idle
		recoil = kick
		aiming = aim
		pending = true
		native_solved = false

	func solve():
		if pending:
			motion.advance_pose(delta, distance, clock, gesture, recoil, aiming)


const PARTS = ["rig", "hips", "chest", "head", "weapon"]
const ARM_PARTS = ["upper", "lower", "wrist", "grip"]
var job := Job.new()
var _bindings := {}

var _hierarchy: RefCounted


func _init(motion, hierarchy = null):
	_hierarchy = hierarchy
	job.motion = motion
	for part in PARTS:
		motion.set(part, _proxy(motion.get(part)))
	for arm in motion.arms:
		for part in ARM_PARTS:
			arm[part] = _proxy(arm[part])
	for leg in motion.legs:
		for index in leg.size():
			leg[index] = _proxy(leg[index])
	# Immutable rig/role data is captured once. The native kernel samples only
	# compact motion state and these node-free local transforms for each batch.
	job.native_parts = [motion.rig, motion.hips, motion.chest, motion.head, motion.weapon]
	job.native_config = PackedFloat64Array(
		[
			motion.rig.scale.z,
			motion._role[0],
			motion._role[1],
			motion._role[6],
			motion._role[3],
			1.0 if motion._role[4] else 0.0,
			motion._role[5].x,
			motion._role[5].y,
			motion.head_rest.x,
			motion.head_rest.y,
			motion.head_rest.z,
		]
	)
	for arm in motion.arms:
		for part in ARM_PARTS:
			job.native_parts.append(arm[part])
		for vector in [arm.upper_rest, arm.lower_rest, arm.pole]:
			job.native_config.append_array(PackedFloat64Array([vector.x, vector.y, vector.z]))
	for leg in motion.legs:
		job.native_parts.append_array(leg)


func _proxy(node: Node3D):
	if not _bindings.has(node):
		var pose = _hierarchy.bind_node(node) if _hierarchy != null else PoseTransform.new()
		pose.transform = node.transform
		_bindings[node] = pose
	return _bindings[node]


func begin():
	job.pending = false
	job.motion.deferred_job = job


func end():
	job.motion.deferred_job = null


func publish():
	for node in _bindings:
		if is_instance_valid(node) and node.transform != _bindings[node].transform:
			node.transform = _bindings[node].transform


func release():
	end()
	publish()
	var originals := {}
	for node in _bindings:
		originals[_bindings[node]] = node
	var motion = job.motion
	for part in PARTS:
		motion.set(part, originals[motion.get(part)])
	for arm in motion.arms:
		for part in ARM_PARTS:
			arm[part] = originals[arm[part]]
	for leg in motion.legs:
		for index in leg.size():
			leg[index] = originals[leg[index]]
	_bindings.clear()
