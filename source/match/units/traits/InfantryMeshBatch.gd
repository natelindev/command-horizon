extends RefCounted

# Run after equipment and ObjectMaterials.apply, before posing the rig. Only
# decorative siblings are baked: articulated parents and gameplay markers stay
# intact. Cache keys retain immutable source resources, avoiding instance-ID reuse.
static var _meshes = {}
const MAX_CACHED_MESHES = 256
const CHANNELS = [
	Mesh.ARRAY_VERTEX,
	Mesh.ARRAY_NORMAL,
	Mesh.ARRAY_TANGENT,
	Mesh.ARRAY_COLOR,
	Mesh.ARRAY_TEX_UV,
	Mesh.ARRAY_TEX_UV2
]


static func apply(rig):
	var carried = load("res://source/match/units/traits/InfantryMotion.gd").CARRIED
	_batch(rig, carried)


static func _batch(parent, carried):
	var groups = {}
	for child in parent.get_children():
		_batch(child, carried)
		if not _eligible(child, carried):
			continue
		var material = child.get_active_material(0)
		var key = [
			material,
			child.mesh.surface_get_format(0),
			child.visible,
			child.cast_shadow,
			child.layers,
			child.gi_mode
		]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(child)
	for key in groups:
		var pieces = groups[key]
		if pieces.size() < 2:
			continue
		var source_key = []
		for piece in pieces:
			source_key.append([piece.mesh, piece.transform])
		if not _meshes.has(source_key):
			# Equipment may use fresh primitives; cap retained resources across saves.
			if _meshes.size() >= MAX_CACHED_MESHES:
				_meshes.erase(_meshes.keys()[0])
			_meshes[source_key] = _merge(pieces)
		var batch = MeshInstance3D.new()
		batch.name = "InfantryDetailBatch"
		batch.mesh = _meshes[source_key]
		batch.material_override = key[0]
		batch.visible = key[2]
		batch.cast_shadow = key[3]
		batch.layers = key[4]
		batch.gi_mode = key[5]
		parent.add_child(batch)
		for piece in pieces:
			piece.free()


static func _eligible(node, carried):
	if not node is MeshInstance3D or not node.mesh is ArrayMesh or node.get_child_count() > 0:
		return false
	# These surfaces are public material/geometry inspection points as well as
	# artwork (ObjectMaterialsRegression and InfantryRedesignRegression).
	if str(node.name) in carried or str(node.name) in ["Jacket", "Face", "BallisticLens"]:
		return false
	if node.get_script() != null or not node.get_meta_list().is_empty():
		return false
	if node.skin != null or node.mesh.get_blend_shape_count() > 0:
		return false
	if (
		node.mesh.get_surface_count() != 1
		or node.mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES
	):
		return false
	# Nonstandard rendering behavior needs its own instance. Infantry decorations
	# use the defaults below; do not silently discard future renderer properties.
	if node.material_overlay != null or node.transparency != 0 or node.top_level:
		return false
	if node.visibility_range_begin != 0 or node.visibility_range_end != 0:
		return false
	if node.extra_cull_margin != 0 or node.custom_aabb != AABB() or node.lod_bias != 1:
		return false
	if node.ignore_occlusion_culling:
		return false
	if absf(node.basis.determinant()) < .000001:
		return false
	var material = node.get_active_material(0)
	if material == null or material.resource_name.begins_with("TeamColor"):
		return false
	# Optical faces and markings remain individually addressable. Standard
	# materials are accepted only with an authoritative semantic resource name;
	# unnamed kit materials must first pass through ObjectMaterials.apply.
	if material is StandardMaterial3D:
		if material.resource_name.is_empty():
			return false
		if not load("res://source/match/ObjectMaterials.gd").eligible(material):
			return false
	elif not material is ShaderMaterial or not material.has_meta("object_surface_family"):
		return false
	var arrays = node.mesh.surface_get_arrays(0)
	for channel in [
		Mesh.ARRAY_CUSTOM0,
		Mesh.ARRAY_CUSTOM1,
		Mesh.ARRAY_CUSTOM2,
		Mesh.ARRAY_CUSTOM3,
		Mesh.ARRAY_BONES,
		Mesh.ARRAY_WEIGHTS
	]:
		if arrays[channel] != null and not arrays[channel].is_empty():
			return false
	return true


static func _merge(pieces):
	var result = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_INDEX] = PackedInt32Array()
	var offset = 0
	for piece in pieces:
		var arrays = piece.mesh.surface_get_arrays(0)
		var transform = piece.transform
		var normal_basis = transform.basis.inverse().transposed()
		var reflected = transform.basis.determinant() < 0
		var vertices = arrays[Mesh.ARRAY_VERTEX]
		for index in vertices.size():
			vertices[index] = transform * vertices[index]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var normals = arrays[Mesh.ARRAY_NORMAL]
		if normals != null:
			for index in normals.size():
				normals[index] = (normal_basis * normals[index]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		var tangents = arrays[Mesh.ARRAY_TANGENT]
		if tangents != null:
			for index in range(0, tangents.size(), 4):
				var tangent = (
					transform.basis
					* Vector3(tangents[index], tangents[index + 1], tangents[index + 2])
				)
				if normals != null and not normals.is_empty():
					var normal = normals[index / 4]
					tangent -= normal * normal.dot(tangent)
				tangent = tangent.normalized()
				tangents[index] = tangent.x
				tangents[index + 1] = tangent.y
				tangents[index + 2] = tangent.z
				if reflected:
					tangents[index + 3] *= -1
			arrays[Mesh.ARRAY_TANGENT] = tangents
		for channel in CHANNELS:
			if arrays[channel] == null:
				continue
			if result[channel] == null:
				result[channel] = arrays[channel].duplicate()
			else:
				result[channel].append_array(arrays[channel])
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices == null or indices.is_empty():
			indices = PackedInt32Array(range(vertices.size()))
		for index in range(0, indices.size(), 3):
			result[Mesh.ARRAY_INDEX].append(indices[index] + offset)
			result[Mesh.ARRAY_INDEX].append(indices[index + (2 if reflected else 1)] + offset)
			result[Mesh.ARRAY_INDEX].append(indices[index + (1 if reflected else 2)] + offset)
		offset += vertices.size()
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, result)
	return mesh
