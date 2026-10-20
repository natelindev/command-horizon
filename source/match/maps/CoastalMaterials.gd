extends RefCounted


static func weather(model):
	var materials = {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(index)
			if not original is StandardMaterial3D:
				continue
			var key = original.resource_name
			if not (
				"concrete" in key.to_lower()
				or key in ["Coastal basalt", "Coastal weathered strata"]
			):
				continue
			if not materials.has(key):
				var material = ShaderMaterial.new()
				material.shader = load("res://source/shaders/3d/coastal_stone.gdshader")
				material.set_shader_parameter("base_tint", original.albedo_color)
				load("res://source/match/ObjectMaterials.gd").configure_rock(
					material, "concrete" if "concrete" in key.to_lower() else "stone"
				)
				materials[key] = material
			mesh.set_surface_override_material(index, materials[key])
