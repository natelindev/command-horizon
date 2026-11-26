// Local-space projection follows moving parts and does not depend on GLB UVs.
// Mirrored sampling makes opposite image edges meet without a hard tile seam.
// This artwork is a neutral detail mask, deliberately sampled without sRGB conversion.
uniform sampler2D armor_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool armor_panels = false;
uniform float armor_scale = 0.68;
uniform float armor_strength = 0.78;

vec3 surface_weights(vec3 normal) {
	vec3 weights = pow(abs(normal), vec3(4.0));
	return weights / max(dot(weights, vec3(1.0)), 0.0001);
}

vec2 mirrored_surface_uv(vec2 uv) {
	return 1.0 - abs(mod(uv, 2.0) - 1.0);
}

float armor_height_grad(vec2 uv, vec2 ddx, vec2 ddy) {
	return textureGrad(armor_texture, mirrored_surface_uv(uv), ddx, ddy).r;
}

float armor_detail(vec3 point, vec3 normal) {
	vec3 p = point * armor_scale;
	vec3 weights = surface_weights(normal);
	vec2 px = dFdx(p.zy);
	vec2 py = dFdy(p.zy);
	vec2 qx = dFdx(p.xz);
	vec2 qy = dFdy(p.xz);
	vec2 rx = dFdx(p.xy);
	vec2 ry = dFdy(p.xy);
	float value = 0.0;
	if (weights.x > 0.04) {
		value += armor_height_grad(p.zy, px, py) * weights.x;
	}
	if (weights.y > 0.04) {
		value += armor_height_grad(p.xz, qx, qy) * weights.y;
	}
	if (weights.z > 0.04) {
		value += armor_height_grad(p.xy, rx, ry) * weights.z;
	}
	// Retain authored brightness on open plate centers while darkening panel joints sharply.
	float norm = clamp(value / 0.75, 0.35, 1.15);
	float seam = smoothstep(0.55, 0.88, norm);
	float crisp = mix(norm * 0.72, norm * 1.04, seam);
	return mix(1.0, clamp(crisp, 0.36, 1.16), armor_strength);
}

vec3 armor_relief_normal(vec3 point, vec3 local_normal, mat3 to_view, vec3 view_normal, float strength) {
	vec3 n = normalize(local_normal);
	vec3 weights = surface_weights(n);
	vec3 p = point * armor_scale;
	float eps = 0.008;
	vec2 px = dFdx(p.zy);
	vec2 py = dFdy(p.zy);
	vec2 qx = dFdx(p.xz);
	vec2 qy = dFdy(p.xz);
	vec2 rx = dFdx(p.xy);
	vec2 ry = dFdy(p.xy);
	vec3 slope = vec3(0.0);
	if (weights.x > 0.04) {
		float h0 = armor_height_grad(p.zy, px, py);
		float dx = armor_height_grad(p.zy + vec2(eps, 0.0), px, py) - h0;
		float dy = armor_height_grad(p.zy + vec2(0.0, eps), px, py) - h0;
		slope += vec3(0.0, -dy, -dx) * weights.x;
	}
	if (weights.y > 0.04) {
		float h0 = armor_height_grad(p.xz, qx, qy);
		float dx = armor_height_grad(p.xz + vec2(eps, 0.0), qx, qy) - h0;
		float dy = armor_height_grad(p.xz + vec2(0.0, eps), qx, qy) - h0;
		slope += vec3(-dx, 0.0, -dy) * weights.y;
	}
	if (weights.z > 0.04) {
		float h0 = armor_height_grad(p.xy, rx, ry);
		float dx = armor_height_grad(p.xy + vec2(eps, 0.0), rx, ry) - h0;
		float dy = armor_height_grad(p.xy + vec2(0.0, eps), rx, ry) - h0;
		slope += vec3(-dx, -dy, 0.0) * weights.z;
	}
	slope = (slope / eps) * 0.045 * strength;
	slope -= n * dot(n, slope);
	return normalize(view_normal + to_view * slope);
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
	// Grime settles where little sky reaches; chipped paint catches bright steel highlights.
	color = mix(color, color * vec3(0.74, 0.65, 0.54), (1.0 - occlusion) * 0.85);
	color = mix(color, vec3(0.72, 0.73, 0.70), wear * 0.72);
	return color * mix(0.28, 1.04, occlusion);
}

// Road dust climbs the lower metre of hulls and walls; flying units stay clean.
vec3 ground_dust(vec3 color, float height) {
	float dust = (1.0 - smoothstep(0.05, 0.9, height)) * 0.34;
	return mix(color, vec3(0.42, 0.37, 0.29), dust);
}

float weathered_roughness(float roughness, vec4 weathering) {
	return clamp(roughness + (1.0 - weathering.r) * 0.18 - (1.0 - weathering.a) * 0.28, 0.14, 1.0);
}
