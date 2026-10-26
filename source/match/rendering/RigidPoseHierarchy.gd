extends RefCounted


## Only the coordinator owns nodes. Jobs own parent-indexed transforms and write
## disjoint palettes; no SceneTree reads or writes happen on worker threads.
class Pose:
	extends "res://source/match/rendering/InfantryPoseWorker.gd".PoseTransform
	var parent: RefCounted
	var index := 0

	var global_transform: Transform3D:
		get:
			return parent.global_transform * transform if parent != null else transform

	func get_parent():
		return parent

	func to_local(point: Vector3) -> Vector3:
		return global_transform.affine_inverse() * point


class Job:
	extends RefCounted
	var native: RefCounted
	var native_rig: RefCounted
	var direct_palette := false
	var poses: Array = []
	var parents := PackedInt32Array()
	var worlds: Array[Transform3D] = []
	var anchors := PackedInt32Array()
	var palette: Array[Transform3D] = []

	func solve():
		if native_rig != null:
			if direct_palette:
				native_rig.solve_worlds()
			else:
				native_rig.solve_palette(palette)
			return
		if native != null:
			native.solve_hierarchy(poses, parents, anchors, palette)
			return
		for index in poses.size():
			var local: Transform3D = poses[index].transform
			worlds[index] = worlds[parents[index]] * local if parents[index] >= 0 else local
		for index in anchors.size():
			palette[index] = worlds[anchors[index]]


const PARTS = ["_turret", "_barrel"]
const LISTS = ["_legs", "_rotors", "_tools", "_stabilizers", "_antennas"]
var job := Job.new()
var root: RefCounted
var _geometry: Node3D
var _bindings := {}
var _originals := {}


func _init(geometry: Node3D, anchors: Array, native = null):
	job.native = native
	if (
		(
			"--native-pose-rigs" in OS.get_cmdline_user_args()
			or "--native-presentation" in OS.get_cmdline_user_args()
		)
		and ClassDB.class_exists("CopperfinPoseRig")
		and geometry.find_children("*", "Node3D", true, false).size() < 4096
	):
		job.native_rig = ClassDB.instantiate("CopperfinPoseRig")
	_geometry = geometry
	root = bind_node(geometry)
	root.transform = geometry.global_transform
	for anchor in anchors:
		job.anchors.append(bind_node(anchor).index)
	job.palette.resize(anchors.size())
	if job.native_rig != null:
		var configured: bool = job.native_rig.configure_anchors(job.anchors)
		assert(configured)


func bind_node(node):
	if node == null:
		return null
	if _bindings.has(node):
		return _bindings[node]
	var parent_pose = bind_node(node.get_parent()) if node != _geometry else null
	var pose: RefCounted
	if job.native_rig != null:
		pose = job.native_rig.add_part(
			parent_pose.index if parent_pose != null else -1, node.transform
		)
	else:
		pose = Pose.new()
		pose.transform = node.transform
		pose.parent = parent_pose
		pose.index = job.poses.size()
	_bindings[node] = pose
	_originals[pose] = node
	job.poses.append(pose)
	job.parents.append(parent_pose.index if parent_pose != null else -1)
	job.worlds.append(Transform3D.IDENTITY)
	return pose


func remap(visual, enabled: bool):
	for part in PARTS:
		visual.set(part, _map(visual.get(part), enabled))
	for part in LISTS:
		var mapped := []
		for node in visual.get(part):
			mapped.append(_map(node, enabled))
		visual.set(part, mapped)
	var rests := {}
	for node in visual._rests:
		rests[_map(node, enabled)] = visual._rests[node]
	visual._rests = rests
	if visual._wheel_motion != null:
		for wheel in visual._wheel_motion.wheels:
			wheel.pivot = _map(wheel.pivot, enabled)
	if visual._walker != null:
		for leg in visual._walker.legs:
			for part in ["node", "knee", "ankle"]:
				leg.set(part, _map(leg.get(part), enabled))
	if visual._muzzle != null:
		bind_node(visual._muzzle)
	# Research animation shares the authored sensor with BastionVisuals. Both
	# writers must target the same pose; its scene node remains parked as well.
	var activity = visual.get_parent().get_node_or_null("StructureActivity")
	if activity != null and activity._sensor != null:
		activity._sensor = _map(activity._sensor, enabled)


func _map(value, enabled: bool):
	if value == null:
		return null
	return bind_node(value) if enabled else _originals[value]


func world_for(node: Node3D) -> Transform3D:
	return world_for_pose(_bindings[node])


func world_for_pose(pose) -> Transform3D:
	if job.native_rig != null:
		return job.native_rig.global_pose(pose.index)
	if job.native != null:
		return job.native.global_pose(job.poses, job.parents, pose.index)
	return pose.global_transform


func publish():
	# Explicit materialization for cloning/fallback only, never the normal tick.
	for node in _bindings:
		if is_instance_valid(node):
			if node == _geometry:
				node.global_transform = root.transform
			else:
				node.transform = _bindings[node].transform
