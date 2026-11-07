# Independent guard clauses keep validation and eligibility paths explicit.
# gdlint: disable=max-returns
extends RefCounted
const Lods = preload("res://source/match/rendering/RigidMeshLods.gd")
const CUSTOM_FLAGS = (
	(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	| (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
)

# Per-match caches: model materials must not retain a previous match's pose texture.
var _buckets := {}


func _bucket(key: String) -> Dictionary:
	return _buckets.get_or_add(key, {})


func setup(poses: Texture2D):
	_bucket("gpu_pose_texture").texture = poses


func _material(material: Material) -> Material:
	var cache = _bucket("gpu_pose_material_prototype")
	if cache.has(material):
		return cache[material]
	var result: ShaderMaterial = (
		material.duplicate() if material is ShaderMaterial else ShaderMaterial.new()
	)
	# The complete articulated batch has one posed occlusion overlay. A source
	# pass uses ordinary mesh coordinates and must not be copied into the batch.
	result.next_pass = null
	var shader := Shader.new()
	var original: String = (
		material.shader.code if material is ShaderMaterial else _standard(material, result)
	)
	original = original.replace("\r\n", "\n").replace("void vertex()\n{", "void vertex() {")
	# Belt deformation is authored in source-local coordinates. Extract that
	# unchanged vertex body before injecting the articulated pose transform.
	var track_body := ""
	if (
		material is ShaderMaterial
		and material.shader.resource_path.ends_with("track_motion.gdshader")
	):
		var start := original.find("void vertex() {") + "void vertex() {".length()
		var finish := original.find("\n}", start)
		track_body = original.substr(start, finish - start)
		original = original.erase(start, finish - start)
		original = original.replace("instance uniform float track_travel = 0.0;", "")
	var code: String = original.replace(
		'#include "res://source/shaders/3d/object_surface.gdshaderinc"',
		FileAccess.get_file_as_string("res://source/shaders/3d/object_surface.gdshaderinc")
	)
	code = code.replace(
		'#include "res://source/shaders/3d/surface_detail.gdshaderinc"',
		FileAccess.get_file_as_string("res://source/shaders/3d/surface_detail.gdshaderinc")
	)
	# Inline detail uniforms before building the material palette and grouping
	# sampler bindings. Preserve each faction's roughness/normal response.
	code = code.replace(
		'#include "res://source/shaders/3d/metal_detail.gdshaderinc"',
		FileAccess.get_file_as_string("res://source/shaders/3d/metal_detail.gdshaderinc")
	)
	code = (
		code
		. replace(
			"void vertex() {",
			"""uniform sampler2D pose_palette : filter_nearest, repeat_disable;
uniform sampler2D material_palette : filter_nearest, repeat_disable;
varying flat int gpu_material_row;
void vertex() {
	gpu_material_row = int(floor(CUSTOM3.w / 8192.0));
	int pose_index = int(mod(CUSTOM3.w, 8192.0) + INSTANCE_CUSTOM.x + 0.5);
	vec4 row0 = texelFetch(pose_palette, ivec2(0, pose_index), 0);
	vec4 row1 = texelFetch(pose_palette, ivec2(1, pose_index), 0);
	vec4 row2 = texelFetch(pose_palette, ivec2(2, pose_index), 0);
	mat3 pose_basis = transpose(mat3(row0.xyz, row1.xyz, row2.xyz));
	mat3 source_basis = mat3(CUSTOM2.xyz, CUSTOM3.xyz, vec3(CUSTOM0.w, CUSTOM1.w, CUSTOM2.w));
	vec3 posed = pose_basis * VERTEX + vec3(row0.w, row1.w, row2.w);
	mat3 original_model = mat3(MODEL_MATRIX) * pose_basis * source_basis;
	mat3 original_view = mat3(VIEW_MATRIX) * original_model;
	VERTEX = posed;
	NORMAL = abs(determinant(pose_basis)) > 0.000001
		? normalize(transpose(inverse(pose_basis)) * NORMAL) : vec3(0.0, 1.0, 0.0);
	TANGENT = normalize(pose_basis * TANGENT);
	BINORMAL = normalize(pose_basis * BINORMAL);
"""
		)
	)
	if not track_body.is_empty():
		code = (
			code
			. replace(
				"vec3 posed = pose_basis * VERTEX + vec3(row0.w, row1.w, row2.w);",
				(
					"""vec3 source_origin = VERTEX - source_basis * CUSTOM0.xyz;
	VERTEX = CUSTOM0.xyz;
	NORMAL = CUSTOM1.xyz;
	// Column 3 is copied without interpolation, matching the original belt's
	// discrete travel cadence even when its wrapped distance crosses zero.
	float track_travel = texelFetch(pose_palette, ivec2(3, pose_index), 0).x;
"""
					+ track_body
					+ """
	VERTEX = source_basis * VERTEX + source_origin;
	NORMAL = normalize(transpose(inverse(source_basis)) * NORMAL);
	vec3 posed = pose_basis * VERTEX + vec3(row0.w, row1.w, row2.w);"""
				)
			)
		)
	code = (
		code
		. replace("length(MODEL_MATRIX[0].xyz)", "length(original_model[0])")
		. replace("length(MODEL_MATRIX[1].xyz)", "length(original_model[1])")
		. replace("length(MODEL_MATRIX[2].xyz)", "length(original_model[2])")
	)
	code = code.replace("surface_position = VERTEX", "surface_position = CUSTOM0.xyz").replace(
		"normalize(NORMAL / scale)", "normalize(CUSTOM1.xyz / scale)"
	)
	code = code.replace("armor_position = VERTEX", "armor_position = CUSTOM0.xyz").replace(
		"armor_normal = NORMAL", "armor_normal = CUSTOM1.xyz"
	)
	code = code.replace("local_position = VERTEX", "local_position = CUSTOM0.xyz").replace(
		"local_normal = NORMAL", "local_normal = CUSTOM1.xyz"
	)
	# Fine metal grain must follow each articulated source part, not the posed
	# batch coordinates; otherwise moving vehicles slide through their texture.
	code = code.replace("metal_position = VERTEX", "metal_position = CUSTOM0.xyz")
	code = code.replace("fabric_position = VERTEX", "fabric_position = CUSTOM0.xyz").replace(
		"normalize(NORMAL / mesh_scale)", "normalize(CUSTOM1.xyz / mesh_scale)"
	)
	for column in 3:
		code = code.replace("MODELVIEW_MATRIX[%d].xyz" % column, "original_view[%d]" % column)
	var declarations := (
		"uniform sampler2D pose_palette : filter_nearest, "
		+ "repeat_disable;\nuniform sampler2D material_palette : filter_nearest, "
		+ "repeat_disable;\nvarying flat int gpu_material_row;"
	)
	code = code.replace("\r\n", "\n").replace(declarations, "").replace(
		"shader_type spatial;", "shader_type spatial;\n" + declarations
	)
	code = _palette_code(code, material, result)
	code = code.replace(
		"varying flat int gpu_material_row;",
		"varying flat int gpu_material_row;\nvarying flat vec4 gpu_pulse;"
	)
	code = (code.replace(
		"gpu_material_row = int(floor(CUSTOM3.w / 8192.0));",
		(
			"gpu_material_row = int(floor(CUSTOM3.w / 8192.0));\n gpu_pulse = "
			+ "texelFetch(pose_palette, ivec2(3, int(INSTANCE_CUSTOM.x + 0.5)), 0);"
		)
	))
	var end := code.rfind("}")
	code = code.insert(end, "\n EMISSION += gpu_pulse.rgb * gpu_pulse.a * gpu_pulse.a * 0.546;\n")
	var groups = _bucket("gpu_palette_groups")
	var group_key: Array = [code]
	var samplers := RegEx.new()
	samplers.compile("uniform sampler2D (\\w+)")
	for parameter in samplers.search_all(code):
		var value = result.get_shader_parameter(parameter.get_string(1))
		group_key.append([parameter.get_string(1), value])
	if groups.has(group_key):
		cache[material] = groups[group_key]
		return groups[group_key]
	shader.code = code
	# Numeric parameters are stored in the palette; texture bindings remain shared.
	result.shader = shader
	result.set_shader_parameter("material_palette", _bucket("gpu_palette_data").texture)
	groups[group_key] = result
	result.set_shader_parameter("pose_palette", _bucket("gpu_pose_texture").texture)
	cache[material] = result
	return result


func can_merge(pieces: Array) -> bool:
	var rows = _bucket("gpu_palette_rows")
	var new_materials := {}
	for piece in pieces:
		for surface in piece[0].mesh.get_surface_count():
			var material = piece[0].get_active_material(surface)
			if not rows.has(material):
				new_materials[material] = true
	return rows.size() + new_materials.size() <= 1024


func merge(pieces: Array) -> ArrayMesh:
	var groups = {}
	for piece in pieces:
		var source: MeshInstance3D = piece[0]
		for surface in source.mesh.get_surface_count():
			var original := source.get_active_material(surface)
			var material := _material(original)
			if not groups.has(material):
				groups[material] = []
			groups[material].append(
				[source, surface, piece[1], piece[2] + 8192 * _bucket("gpu_palette_rows")[original]]
			)
	var output := ArrayMesh.new()
	for material in groups:
		var result := []
		result.resize(Mesh.ARRAY_MAX)
		result[Mesh.ARRAY_VERTEX] = PackedVector3Array()
		result[Mesh.ARRAY_NORMAL] = PackedVector3Array()
		result[Mesh.ARRAY_COLOR] = PackedColorArray()
		result[Mesh.ARRAY_TANGENT] = PackedFloat32Array()
		result[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
		result[Mesh.ARRAY_TEX_UV2] = PackedVector2Array()
		result[Mesh.ARRAY_INDEX] = PackedInt32Array()
		for channel in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
			result[channel] = PackedFloat32Array()
		var offset := 0
		var lod_parts := []
		for entry in groups[material]:
			var source: MeshInstance3D = entry[0]
			var arrays := source.mesh.surface_get_arrays(entry[1])
			var transform: Transform3D = entry[2]
			var normal_basis := transform.basis.inverse().transposed()
			var reflected := transform.basis.determinant() < 0
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in vertices.size():
				var normal := normals[index] if normals.size() > index else Vector3.UP
				result[Mesh.ARRAY_VERTEX].append(transform * vertices[index])
				result[Mesh.ARRAY_NORMAL].append((normal_basis * normal).normalized())
				result[Mesh.ARRAY_CUSTOM0].append_array(
					PackedFloat32Array(
						[
							vertices[index].x,
							vertices[index].y,
							vertices[index].z,
							transform.basis.z.x
						]
					)
				)
				result[Mesh.ARRAY_CUSTOM1].append_array(
					PackedFloat32Array([normal.x, normal.y, normal.z, transform.basis.z.y])
				)
				result[Mesh.ARRAY_CUSTOM2].append_array(
					PackedFloat32Array(
						[
							transform.basis.x.x,
							transform.basis.x.y,
							transform.basis.x.z,
							transform.basis.z.z
						]
					)
				)
				result[Mesh.ARRAY_CUSTOM3].append_array(
					PackedFloat32Array(
						[transform.basis.y.x, transform.basis.y.y, transform.basis.y.z, entry[3]]
					)
				)
				result[Mesh.ARRAY_COLOR].append(
					(
						arrays[Mesh.ARRAY_COLOR][index]
						if (
							arrays[Mesh.ARRAY_COLOR] != null
							and arrays[Mesh.ARRAY_COLOR].size() > index
						)
						else Color.WHITE
					)
				)
				for channel in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
					result[channel].append(
						(
							arrays[channel][index]
							if arrays[channel] != null and arrays[channel].size() > index
							else Vector2.ZERO
						)
					)
				var tangent := Vector3.RIGHT
				var sign := 1.0
				if (
					arrays[Mesh.ARRAY_TANGENT] != null
					and arrays[Mesh.ARRAY_TANGENT].size() >= index * 4 + 4
				):
					var values: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
					tangent = Vector3(
						values[index * 4], values[index * 4 + 1], values[index * 4 + 2]
					)
					sign = values[index * 4 + 3]
				tangent = (transform.basis * tangent).normalized()
				result[Mesh.ARRAY_TANGENT].append_array(
					PackedFloat32Array(
						[tangent.x, tangent.y, tangent.z, sign * (-1 if reflected else 1)]
					)
				)
			var indices: PackedInt32Array = (
				arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			)
			if indices.is_empty():
				indices = PackedInt32Array(range(vertices.size()))
			var levels := {}
			if source.mesh is ArrayMesh:
				var cached = _bucket("source_mesh_lods")
				var key = [source.mesh, entry[1]]
				if not cached.has(key):
					cached[key] = Lods.read(source.mesh, entry[1])
				levels = cached[key]
			var world_basis := source.global_basis if source.is_inside_tree() else source.basis
			var scale := world_basis.get_scale().abs()
			(
				lod_parts
				. append(
					{
						"indices": indices,
						"levels": levels,
						"offset": offset,
						"reflected": reflected,
						"scale": maxf(scale.x, maxf(scale.y, scale.z)),
					}
				)
			)
			for index in range(0, indices.size(), 3):
				result[Mesh.ARRAY_INDEX].append(indices[index] + offset)
				result[Mesh.ARRAY_INDEX].append(indices[index + (2 if reflected else 1)] + offset)
				result[Mesh.ARRAY_INDEX].append(indices[index + (1 if reflected else 2)] + offset)
			offset += vertices.size()
		output.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES, result, [], Lods.combine(lod_parts), CUSTOM_FLAGS
		)
		output.surface_set_material(output.get_surface_count() - 1, material)
	return output


func _standard(material: StandardMaterial3D, result: ShaderMaterial) -> String:
	var modes := ""
	if material.cull_mode == BaseMaterial3D.CULL_DISABLED:
		modes += "render_mode cull_disabled;\n"
	if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		modes += "render_mode unshaded;\n"
	var code := """shader_type spatial;
__RENDER_FLAGS__
uniform vec4 tint : source_color;
uniform float metalness;
uniform float roughness;
uniform float specular;
uniform vec4 glow : source_color;
uniform float glow_power;
uniform vec3 uv_scale;
uniform vec3 uv_offset;
uniform sampler2D color_map : source_color, hint_default_white;
uniform sampler2D glow_map : source_color, hint_default_white;
uniform sampler2D normal_map : hint_normal;
uniform float normal_scale;
void vertex() { UV = UV * uv_scale.xy + uv_offset.xy; }
void fragment() {
	vec4 color = tint * texture(color_map, UV);
	VERTEX_COLOR
	ALBEDO = color.rgb;
	METALLIC = metalness;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	GLOW
	NORMAL_MAPPING
	ALPHA_MODE
}
"""
	result.set_shader_parameter("tint", material.albedo_color)
	result.set_shader_parameter("metalness", material.metallic)
	result.set_shader_parameter("roughness", material.roughness)
	result.set_shader_parameter("specular", material.metallic_specular)
	result.set_shader_parameter("uv_scale", material.uv1_scale)
	result.set_shader_parameter("uv_offset", material.uv1_offset)
	if material.albedo_texture != null:
		result.set_shader_parameter("color_map", material.albedo_texture)
	result.set_shader_parameter("glow", material.emission)
	result.set_shader_parameter(
		"glow_power", material.emission_energy_multiplier if material.emission_enabled else 0.0
	)
	if material.emission_texture != null:
		result.set_shader_parameter("glow_map", material.emission_texture)
	if material.normal_enabled:
		result.set_shader_parameter("normal_map", material.normal_texture)
		result.set_shader_parameter("normal_scale", material.normal_scale)
	return (
		code
		. replace("__RENDER_FLAGS__", modes)
		. replace("VERTEX_COLOR", "color *= COLOR;" if material.vertex_color_use_as_albedo else "")
		. replace("GLOW", "EMISSION = glow.rgb * glow_power * texture(glow_map, UV).rgb;")
		. replace(
			"NORMAL_MAPPING",
			(
				"NORMAL_MAP = texture(normal_map, UV).rgb; NORMAL_MAP_DEPTH = normal_scale;"
				if material.normal_enabled
				else ""
			)
		)
		. replace(
			"ALPHA_MODE",
			(
				"ALPHA = color.a;"
				if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				else ""
			)
		)
	)


func _palette_code(code: String, original: Material, values: ShaderMaterial) -> String:
	var rows = _bucket("gpu_palette_rows")
	var state = _bucket("gpu_palette_data")
	if not state.has("image"):
		state.image = Image.create(32, 1024, false, Image.FORMAT_RGBAF)
		state.texture = ImageTexture.create_from_image(state.image)
	var row := rows.size()
	rows[original] = row
	var declarations := RegEx.new()
	declarations.compile("(?<!global )uniform (float|bool|vec3|vec4) (\\w+)([^;]*);")
	var column := 0
	for found in declarations.search_all(code):
		var kind := found.get_string(1)
		var name := found.get_string(2)
		var tail := found.get_string(3)
		var value = values.get_shader_parameter(name)
		if value == null and original is ShaderMaterial:
			value = RenderingServer.shader_get_parameter_default(original.shader.get_rid(), name)
		if value == null:
			value = 0.0
		var packed := Color(0, 0, 0, 0)
		if value is Color:
			packed = value.srgb_to_linear() if "source_color" in tail else value
		elif value is Vector3:
			packed = Color(value.x, value.y, value.z, 0)
		else:
			packed.r = float(value)
		state.image.set_pixel(column, row, packed)
		var access := "texelFetch(material_palette, ivec2(%d, gpu_material_row), 0)" % column
		if kind == "float":
			access += ".r"
		elif kind == "bool":
			access += ".r > 0.5"
		elif kind == "vec3":
			access += ".rgb"
		code = code.replace(found.get_string(), "#define %s (%s)" % [name, access])
		column += 1
	assert(column <= 32 and row < 1024)
	state.texture.update(state.image)
	return code


func supports(material: Material) -> bool:
	if material == null:
		return false
	if material.next_pass != null and not material.next_pass.has_meta("unit_occlusion"):
		return false
	if material is ShaderMaterial:
		return (
			material.has_meta("object_surface_family")
			or (
				material.shader.resource_path.get_file()
				in [
					"armor_surface.gdshader",
					"frontier_surface.gdshader",
					"infantry_fabric.gdshader",
					"track_motion.gdshader"
				]
			)
		)
	if not material is StandardMaterial3D:
		return false
	# Retain the native renderer for optical surfaces and advanced material
	# features. The palette shader supports simple opaque lit/emissive finishes.
	if (
		material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
		or material.cull_mode == BaseMaterial3D.CULL_FRONT
	):
		return false
	if (
		material.albedo_texture != null
		or material.emission_texture != null
		or material.normal_enabled
	):
		return false
	for feature in [
		"rim_enabled",
		"clearcoat_enabled",
		"anisotropy_enabled",
		"subsurf_scatter_enabled",
		"refraction_enabled",
		"detail_enabled",
		"heightmap_enabled",
		"ao_enabled",
		"grow_enabled",
		"proximity_fade_enabled",
		"distance_fade_mode"
	]:
		if material.get(feature):
			return false
	return material.metallic_texture == null and material.roughness_texture == null
