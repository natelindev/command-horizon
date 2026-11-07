extends RefCounted

## A material pass on live mobile geometry, so fog visibility, hidden parts and
## articulated poses remain authoritative. No duplicate rig or per-frame scan.
const SHADER = preload("res://source/shaders/3d/unit_occlusion.gdshader")
const Cache = preload("res://source/utils/RuntimeCache.gd")
const MAX_MATERIALS = 1024


static func apply(unit):
	if not unit.has_node("Movement"):
		return
	var cache = Cache.bucket("unit_occlusion_surfaces")
	var pass_material = material(unit.color, unit.radius)
	for mesh in unit.get_node("Geometry").find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.has_meta("animated_track"):
			# The solid hull supplies the silhouette; individual moving tread shoes
			# need no extra draw or second deformation pass.
			continue
		if mesh.material_override != null:
			mesh.material_override = _surface(mesh.material_override, pass_material, cache)
			continue
		for surface in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(surface)
			mesh.set_surface_override_material(surface, _surface(original, pass_material, cache))


static func _surface(original, pass_material, cache):
	if original == null:
		return null
	if original.next_pass != null:
		if original.next_pass == pass_material or not original.next_pass.has_meta("unit_occlusion"):
			return original
		# Ownership/color refresh replaces only our pass, keeping the finish.
		original = original.get_meta("occlusion_original", original)
	var key = [original, pass_material]
	if not cache.has(key):
		if cache.size() >= MAX_MATERIALS:
			cache.erase(cache.keys()[0])
		var copy = original.duplicate()
		copy.next_pass = pass_material
		copy.set_meta("occlusion_original", original)
		cache[key] = copy
	return cache[key]


static func material(color: Color, radius: float, poses: Texture2D = null) -> ShaderMaterial:
	var cache = Cache.bucket("unit_occlusion_passes")
	var bias = maxf(1.0, radius * 2.2)
	var key = [color, bias, poses]
	if cache.has(key):
		return cache[key]
	if cache.size() >= MAX_MATERIALS:
		cache.erase(cache.keys()[0])
	var result = ShaderMaterial.new()
	result.shader = SHADER
	if poses != null:
		var shader = Shader.new()
		shader.code = (
			SHADER
			. code
			. replace(
				"void vertex() {",
				"""uniform sampler2D pose_palette : filter_nearest, repeat_disable;
void vertex() {
	int pose_index = int(mod(CUSTOM3.w, 8192.0) + INSTANCE_CUSTOM.x + 0.5);
	vec4 row0 = texelFetch(pose_palette, ivec2(0, pose_index), 0);
	vec4 row1 = texelFetch(pose_palette, ivec2(1, pose_index), 0);
	vec4 row2 = texelFetch(pose_palette, ivec2(2, pose_index), 0);
	mat3 pose_basis = transpose(mat3(row0.xyz, row1.xyz, row2.xyz));
	VERTEX = pose_basis * VERTEX + vec3(row0.w, row1.w, row2.w);
	NORMAL = abs(determinant(pose_basis)) > 0.000001
		? normalize(transpose(inverse(pose_basis)) * NORMAL) : vec3(0.0, 1.0, 0.0);
"""
			)
		)
		result.shader = shader
		result.set_shader_parameter("pose_palette", poses)
	result.set_shader_parameter("silhouette_color", color)
	result.set_shader_parameter("occlusion_bias", bias)
	result.set_meta("unit_occlusion", true)
	cache[key] = result
	return result
