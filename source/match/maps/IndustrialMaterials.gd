extends RefCounted


static func weather(model):
	var materials = {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(index)
			if not original is StandardMaterial3D:
				continue
			var key = original.resource_name
			var label = key.to_lower()
			if not (
				"concrete" in label or "brick" in label or "panels" in label or "roof" in label
			):
				continue
			if not materials.has(key):
				var material = ShaderMaterial.new()
				material.shader = load("res://source/shaders/3d/district_surface.gdshader")
				material.set_shader_parameter("base_tint", original.albedo_color)
				material.set_shader_parameter("metallic", original.metallic)
				materials[key] = material
			mesh.set_surface_override_material(index, materials[key])
