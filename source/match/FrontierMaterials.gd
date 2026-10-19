extends RefCounted

const SURFACE = preload("res://source/shaders/3d/frontier_surface.gdshader")
const Textures = preload("res://source/match/SurfaceTextures.gd")
static var _materials = {}


static func apply(model):
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(index)
			if not original is StandardMaterial3D:
				continue
			var key = original.resource_name
			# Preserve replaceable team colors, glass, and dark mechanical recesses.
			if not (
				key
				in [
					"Frontier_Ceramic",
					"Frontier_Secondary",
					"Frontier_Canvas",
					"Frontier_Titanium",
					"Frontier_Foundation"
				]
			):
				continue
			if not _materials.has(key):
				var material = ShaderMaterial.new()
				material.shader = SURFACE
				var tint = original.albedo_color
				if key == "Frontier_Canvas":
					tint = Color("8a8060")
				material.set_shader_parameter("base_color", tint)
				material.set_shader_parameter("metalness", original.metallic * 0.6)
				material.set_shader_parameter("fabric", key == "Frontier_Canvas")
				Textures.configure_armor(
					material, key in ["Frontier_Ceramic", "Frontier_Secondary", "Frontier_Titanium"]
				)
				_materials[key] = material
			mesh.set_surface_override_material(index, _materials[key])
