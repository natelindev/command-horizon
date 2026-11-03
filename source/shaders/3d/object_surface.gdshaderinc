#include "res://source/shaders/3d/metal_detail.gdshaderinc"

uniform bool metal_finish_enabled = false;
// Object-space triplanar textures also work on UV-less generated models and
// merged MultiMeshes. Physical scale is retained without swimming when moving.
uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_roughness : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 base_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float metalness = 0.0;
uniform float base_roughness = 0.85;
uniform float base_specular = 0.5;
uniform vec3 texture_scale = vec3(1.0);
uniform float detail_strength = 0.65;
uniform float normal_strength = 0.5;
uniform bool has_normal = false;
uniform bool has_roughness = false;
uniform bool vertex_tint = false;
uniform float leaf_transmission = 0.0;
// A per-material control for rendered comparisons, independent of ground detail.
uniform float object_detail = 1.0;
#include "res://source/shaders/3d/foliage_response.gdshaderinc"

varying vec3 surface_position;
varying vec3 metal_position;
varying vec3 surface_geometric_normal;
varying mat3 surface_to_view;

void vertex() {
	vec3 scale = max(vec3(length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)), vec3(0.0001));
	metal_position = VERTEX * scale;
	surface_position = metal_position * texture_scale;
	surface_geometric_normal = normalize(NORMAL / scale);
	if (leaf_transmission > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 push = foliage_push(world, foliage_impulse_0, foliage_strengths.x)
			+ foliage_push(world, foliage_impulse_1, foliage_strengths.y)
			+ foliage_push(world, foliage_impulse_2, foliage_strengths.z)
			+ foliage_push(world, foliage_impulse_3, foliage_strengths.w);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * push;
	}
	surface_to_view = mat3(MODELVIEW_MATRIX[0].xyz / scale.x,
		MODELVIEW_MATRIX[1].xyz / scale.y, MODELVIEW_MATRIX[2].xyz / scale.z);
}

vec3 surface_sample(sampler2D image, vec3 p, vec3 weights) {
	return texture(image, p.zy).rgb * weights.x
		+ texture(image, p.xz).rgb * weights.y
		+ texture(image, p.xy).rgb * weights.z;
}

void fragment() {
	vec3 n = normalize(surface_geometric_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	vec3 mean = max(textureLod(surface_color, vec2(0.5), 12.0).rgb, vec3(0.02));
	vec3 scan = surface_sample(surface_color, surface_position, weights);
	// Neutralized scans retain the authored biome/team palette.
	vec3 ratio = scan / mean;
	float luminance = dot(ratio, vec3(0.2126, 0.7152, 0.0722));
	vec3 detail = clamp(mix(vec3(luminance), ratio, 0.18), vec3(0.35), vec3(1.85));
	float amount = detail_strength * object_detail;
	ALBEDO = base_color.rgb * mix(vec3(1.0), detail, amount);
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
	METALLIC = metalness;
	SPECULAR = base_specular;
	ROUGHNESS = base_roughness;
	if (has_roughness) {
		float rough = surface_sample(surface_roughness, surface_position, weights).r;
		ROUGHNESS = clamp(base_roughness + (rough - 0.7) * 0.25 * object_detail, 0.12, 1.0);
	}
	vec3 slope = vec3(0.0);
	if (has_normal) {
		vec2 x = texture(surface_normal, surface_position.zy).xy * 2.0 - 1.0;
		vec2 y = texture(surface_normal, surface_position.xz).xy * 2.0 - 1.0;
		vec2 z = texture(surface_normal, surface_position.xy).xy * 2.0 - 1.0;
		slope = vec3(0.0, x.y, x.x) * weights.x
			+ vec3(y.x, 0.0, y.y) * weights.y + vec3(z.x, z.y, 0.0) * weights.z;
		slope -= n * dot(slope, n);
		vec3 perturbed = normalize(n + slope * normal_strength * object_detail);
		NORMAL = normalize(surface_to_view * perturbed) * (FRONT_FACING ? 1.0 : -1.0);
	}
	float surface_ao = 1.0;
	if (metal_finish_enabled) {
		MetalFinish finish = metal_finish(metal_position, surface_geometric_normal,
			surface_to_view, VERTEX, NORMAL, UV2);
		NORMAL = normalize(mix(NORMAL, finish.normal, object_detail));
		ALBEDO *= mix(1.0, finish.color, object_detail);
		surface_ao = mix(1.0, finish.occlusion, object_detail);
		ROUGHNESS = clamp(ROUGHNESS + finish.roughness_delta * object_detail, 0.12, 1.0);
	}
	// Geometric underside and surface cavity ambient occlusion
	float underside_ao = clamp(n.y * 0.40 + 0.60, 0.35, 1.0);
	float slope_cavity = 1.0;
	if (has_normal) {
		slope_cavity = clamp(1.0 - length(slope) * 0.32 * normal_strength, 0.65, 1.0);
	}
	AO = clamp(surface_ao * underside_ao * slope_cavity, 0.22, 1.0);
	AO_LIGHT_AFFECT = 0.42;

	// Tactical silhouette rim highlight for RTS unit readability
	RIM = 0.26 * object_detail;
	RIM_TINT = 0.40;

	// Leaves remain lit and shadowed; a little transmitted light softens backlit crowns.
	BACKLIGHT = base_color.rgb * leaf_transmission;
}
