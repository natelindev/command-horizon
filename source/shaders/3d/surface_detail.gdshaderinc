// Local-space projection follows moving parts and does not depend on GLB UVs.
// Mirrored sampling makes opposite image edges meet without a hard tile seam.
// This artwork is a neutral detail mask, deliberately sampled without sRGB conversion.
uniform sampler2D armor_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool armor_panels = false;
uniform float armor_scale = 0.4;
uniform float armor_strength = 0.55;

vec3 surface_weights(vec3 normal) {
	vec3 weights = pow(abs(normal), vec3(4.0));
	return weights / max(dot(weights, vec3(1.0)), 0.0001);
}

vec2 mirrored_surface_uv(vec2 uv) {
	return 1.0 - abs(mod(uv, 2.0) - 1.0);
}

float armor_detail(vec3 point, vec3 normal) {
	vec3 p = point * armor_scale;
	vec3 weights = surface_weights(normal);
	float value = texture(armor_texture, mirrored_surface_uv(p.zy)).r * weights.x;
	value += texture(armor_texture, mirrored_surface_uv(p.xz)).r * weights.y;
	value += texture(armor_texture, mirrored_surface_uv(p.xy)).r * weights.z;
	// The source's light paint averages roughly 0.75. Preserve the faction's
	// authored brightness while retaining darker joints and selective wear.
	return mix(1.0, clamp(value / 0.75, 0.45, 1.12), armor_strength);
}

vec3 surface_triplanar_color(sampler2D map, vec3 point, vec3 normal) {
	vec3 weights = surface_weights(normal);
	return texture(map, point.zy).rgb * weights.x
		+ texture(map, point.xz).rgb * weights.y
		+ texture(map, point.xy).rgb * weights.z;
}

// Baked vertex weathering from art/common/weathering.py: rgb is occlusion and
// alpha is 1 - edge wear. Meshes without vertex colors read as unweathered.
vec3 weathered(vec3 color, vec4 weathering, bool painted) {
	float occlusion = weathering.r;
	float wear = painted ? 1.0 - weathering.a : 0.0;
	// Grime settles where little sky reaches; chipped paint shows lighter steel.
	color = mix(color, color * vec3(0.80, 0.72, 0.60), (1.0 - occlusion) * 0.8);
	color = mix(color, vec3(0.62, 0.61, 0.58), wear * 0.65);
	return color * occlusion;
}

// Road dust climbs the lower metre of hulls and walls; flying units stay clean.
vec3 ground_dust(vec3 color, float height) {
	float dust = (1.0 - smoothstep(0.05, 0.9, height)) * 0.32;
	return mix(color, vec3(0.42, 0.37, 0.29), dust);
}

float weathered_roughness(float roughness, vec4 weathering) {
	return clamp(roughness + (1.0 - weathering.r) * 0.15 - (1.0 - weathering.a) * 0.22, 0.15, 1.0);
}
