extends RefCounted


static func weather_stone(model):
	var materials = {}
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(index)
			if not original is StandardMaterial3D:
				continue
			if not original.resource_name.begins_with("Quarry "):
				continue
			var key = original.resource_name
			if not materials.has(key):
				var material = ShaderMaterial.new()
				material.shader = load("res://source/shaders/3d/desert_stone.gdshader")
				material.set_shader_parameter("stone_tint", original.albedo_color)
				load("res://source/match/ObjectMaterials.gd").configure_rock(material)
				materials[key] = material
			mesh.set_surface_override_material(index, materials[key])
