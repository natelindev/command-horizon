extends Node

const BUILD_SHADER = preload("res://source/shaders/3d/construction.gdshader")
var _surfaces = []
var _materials = []
var _phase = 0.0
var _unit


func _ready():
	_unit = get_parent()
	var meshes = _unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false)
	var bounds = AABB()
	# Do not merge with an origin AABB: the site may be far from the world origin.
	if not meshes.is_empty():
		bounds = meshes[0].global_transform * meshes[0].get_aabb()
		for mesh in meshes:
			bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
	for mesh in meshes:
		var original_override = mesh.material_override
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			var material = ShaderMaterial.new()
			material.shader = BUILD_SHADER
			if original is BaseMaterial3D:
				material.set_shader_parameter("base_color", original.albedo_color)
				material.set_shader_parameter("base_metallic", original.metallic)
				material.set_shader_parameter("base_roughness", original.roughness)
				if original.albedo_texture != null:
					material.set_shader_parameter("base_texture", original.albedo_texture)
					material.set_shader_parameter("has_texture", true)
			material.set_shader_parameter("floor_height", bounds.position.y)
			material.set_shader_parameter("total_height", maxf(.1, bounds.size.y))
			_surfaces.append(
				[mesh, surface, mesh.get_surface_override_material(surface), original_override]
			)
			mesh.set_surface_override_material(surface, material)
			_materials.append(material)
		mesh.material_override = null
	refresh()


func _process(delta):
	_phase += delta
	refresh()


func refresh():
	for material in _materials:
		material.set_shader_parameter("progress", _unit._construction_progress)
		material.set_shader_parameter("phase", _phase)


func finish():
	for entry in _surfaces:
		if is_instance_valid(entry[0]):
			entry[0].set_surface_override_material(entry[1], entry[2])
			entry[0].material_override = entry[3]
	queue_free()
