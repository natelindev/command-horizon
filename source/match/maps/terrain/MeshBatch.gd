extends RefCounted

# Shared batching for repeated environment models: one merged mesh per model
# (a surface per material) drawn through a MultiMesh keeps each cover type to
# a few draw calls however many instances or source pieces it has.

const ROOT = "res://assets/models/environment/%s.glb"
const Vegetation = preload("res://source/match/maps/Vegetation.gd")
static var _meshes = {}


static func merged_mesh(asset: String, height: float) -> ArrayMesh:
	var key = "%s@%.3f" % [asset, height]
	if _meshes.has(key):
		return _meshes[key]
	var source = load(ROOT % asset).instantiate()
	Vegetation.fit_height(source, height)
	var tools = {}
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		var local = Transform3D.IDENTITY
		var node = mesh
		while node != source:
			local = node.transform * local
			node = node.get_parent()
		local = source.transform * local
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if not tools.has(material):
				tools[material] = SurfaceTool.new()
				tools[material].begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[material].set_material(material)
			tools[material].append_from(mesh.mesh, surface, local)
	var merged = ArrayMesh.new()
	for material in tools:
		tools[material].commit(merged)
	source.free()
	_meshes[key] = merged
	return merged


static func add(parent: Node, mesh: Mesh, transforms: Array, name: String, shadows = false):
	if transforms.is_empty():
		return null
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])
	var instance = MultiMeshInstance3D.new()
	instance.name = name
	instance.multimesh = multimesh
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if shadows
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	parent.add_child(instance)
	return instance
