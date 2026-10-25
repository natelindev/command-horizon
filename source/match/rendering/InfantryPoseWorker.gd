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
			return transform.basis.get_euler()
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

	func configure(dt: float, travel: float, time: float, idle: float, kick: float, aim: float):
		delta = dt
		distance = travel
		clock = time
		gesture = idle
		recoil = kick
		aiming = aim
		pending = true

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
