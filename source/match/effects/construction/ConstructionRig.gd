extends Node3D

const Cache = preload("res://source/utils/RuntimeCache.gd")

# Shared helpers for faction construction rigs. Static props are batched into one
# MultiMesh per mesh and finish, with per-instance colours, so a site costs a few
# draw calls. Each instance carries a key (usually its height) and a batch shows
# only the instances whose key is within the current threshold.

const BOX = "box"
const ROD = "rod"

var bounds = AABB()  # Structure-local footprint and height.
var progress = 0.0
var activity = 0.0  # 0 while the site waits for builders, 1 while being worked.
var work = 0.0  # Seconds of active building; drives machinery so it halts when idle.
var phase = 0.0
var steady = false
var emit_interval = .22  # Seconds between particle bursts while the site is worked.
var _batches = {}


static func mesh(kind):
	var meshes = Cache.bucket("construction_meshes")
	if not meshes.has(kind):
		if kind == BOX:
			meshes[kind] = BoxMesh.new()
		else:
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = .5
			cylinder.bottom_radius = .5
			cylinder.height = 1.0
			cylinder.radial_segments = 8
			cylinder.rings = 0
			meshes[kind] = cylinder
	return meshes[kind]


static func finish(label, color = Color.WHITE, metallic = 0.0, roughness = .8, glow = 0.0):
	var finishes = Cache.bucket("construction_finishes")
	# Shared by every site. Batched parts pass white and tint per instance colour;
	# primitive meshes without vertex colours keep the albedo unchanged.
	var key = "%s/%s" % [label, color.to_html()]
	if not finishes.has(key):
		var material = StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = metallic
		material.roughness = roughness
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		if glow > 0:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = glow
		finishes[key] = material
	return finishes[key]


static func rod(from, to, thickness):
	# Unit box/cylinder transform spanning two points.
	var axis = to - from
	var up = axis.normalized()
	var side = up.cross(Vector3.FORWARD if absf(up.z) < .9 else Vector3.RIGHT).normalized()
	var front = side.cross(up)
	return Transform3D(Basis(side * thickness, axis, front * thickness), (from + to) * .5)


static func block(center, size, yaw = 0.0):
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center)


func setup(structure_bounds):
	bounds = structure_bounds
	_build()
	for batch in _batches.values():
		_commit(batch)
	update(0.0)


func advance(delta, busy):
	activity = move_toward(activity, 1.0 if busy else 0.0, delta * 2.0)
	work += delta * activity
	update(delta)


func front_height():
	return bounds.position.y + bounds.size.y * lerpf(.025, 1.0, progress)


func site_seed():
	# Stable per-site variation: identical on every client and after a reload.
	var point = get_parent().get_parent().global_position
	return absi(hash(Vector2i(roundi(point.x * 10), roundi(point.z * 10))))


func _build():
	pass


func update(_delta):
	pass


func emit_effects(_effects, _random):
	pass


func _add(
	batch_name,
	kind,
	finish_material,
	instance_transform,
	color = Color.WHITE,
	key = 0.0,
	parent = null
):
	# Moving assemblies pass their own node as parent so the whole batch travels with it.
	if not _batches.has(batch_name):
		_batches[batch_name] = {
			"name": batch_name,
			"kind": kind,
			"material": finish_material,
			"parent": parent if parent != null else self,
			"items": []
		}
	assert(_batches[batch_name].kind == kind, "construction batch mixes meshes")
	_batches[batch_name].items.append([key, instance_transform, color])


func _commit(batch):
	batch.items.sort_custom(func(a, b): return a[0] < b[0])
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh(batch.kind)
	multimesh.instance_count = batch.items.size()
	batch["keys"] = PackedFloat32Array()
	# Upload the entire batch once. Per-instance setters repeatedly cross into
	# the rendering server while a new construction site is being created.
	var buffer = PackedFloat32Array()
	buffer.resize(batch.items.size() * 16)
	for index in batch.items.size():
		var item = batch.items[index]
		batch.keys.append(item[0])
		var pose: Transform3D = item[1]
		var color: Color = item[2]
		var offset = index * 16
		for row in 3:
			buffer[offset + row * 4] = pose.basis.x[row]
			buffer[offset + row * 4 + 1] = pose.basis.y[row]
			buffer[offset + row * 4 + 2] = pose.basis.z[row]
			buffer[offset + row * 4 + 3] = pose.origin[row]
		buffer[offset + 12] = color.r
		buffer[offset + 13] = color.g
		buffer[offset + 14] = color.b
		buffer[offset + 15] = color.a
	multimesh.buffer = buffer
	var node = MultiMeshInstance3D.new()
	node.name = batch.name
	node.multimesh = multimesh
	node.material_override = batch.material
	batch.parent.add_child(node)
	batch["node"] = node
	batch.erase("items")
	batch.erase("parent")


func _reveal(batch_name, threshold):
	var batch = _batches[batch_name]
	batch.node.multimesh.visible_instance_count = batch.keys.bsearch(threshold, false)


func _part(parent, label, kind, part_transform, material, shadows = true):
	var node = MeshInstance3D.new()
	node.name = label
	node.mesh = mesh(kind)
	node.transform = part_transform
	node.material_override = material
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _site_point(local_point):
	return global_transform * local_point
