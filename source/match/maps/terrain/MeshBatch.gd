extends RefCounted

const Cache = preload("res://source/utils/RuntimeCache.gd")

# Shared batching for repeated environment models: one merged mesh per model
# (a surface per material) drawn through a MultiMesh keeps each cover type to
# a few draw calls however many instances or source pieces it has.

const ROOT = "res://assets/models/environment/%s.glb"
const Vegetation = preload("res://source/match/maps/Vegetation.gd")


static func merged_mesh(asset: String, height: float) -> ArrayMesh:
	var meshes = Cache.bucket("terrain_meshes")
	var key = "%s@%.3f" % [asset, height]
	if meshes.has(key):
		return meshes[key]
	var source = load(ROOT % asset).instantiate()
	Vegetation.fit_height(source, height)
	load("res://source/match/ObjectMaterials.gd").apply(source)
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
	meshes[key] = merged
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


## Partition large world dressing into spatial MultiMesh chunks so Godot
## frustum-culls off-camera vegetation and rocks in both main and shadow passes.
static func add_chunked(
	parent: Node, mesh: Mesh, transforms: Array, name: String, shadows = false, chunk_size := 32.0
):
	if transforms.is_empty():
		return
	var cells := {}
	for placement: Transform3D in transforms:
		var cell := Vector2i(
			floori(placement.origin.x / chunk_size), floori(placement.origin.z / chunk_size)
		)
		cells.get_or_add(cell, []).append(placement)
	var keys := cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y if a.y != b.y else a.x < b.x)
	for index in keys.size():
		var chunk_name := name if index == 0 else "%s_%d" % [name, index]
		add(parent, mesh, cells[keys[index]], chunk_name, shadows)
