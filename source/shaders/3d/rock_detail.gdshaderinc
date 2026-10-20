// Fine scanned relief over the biome shader's own strata, snow and salt colors.
uniform sampler2D rock_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float rock_texture_strength = 0.0;
uniform float rock_tile = 3.5;

vec3 rock_weights(vec3 n) {
	vec3 weights = pow(abs(n), vec3(4.0));
	return weights / max(dot(weights, vec3(1.0)), 0.0001);
}

vec3 rock_albedo(vec3 color, vec3 point, vec3 normal) {
	if (rock_texture_strength <= 0.0) {
		return color;
	}
	vec3 p = point / rock_tile;
	vec3 weights = rock_weights(normal);
	vec3 mean = max(textureLod(rock_color, vec2(0.5), 12.0).rgb, vec3(0.02));
	vec3 scan = texture(rock_color, p.zy).rgb * weights.x
		+ texture(rock_color, p.xz).rgb * weights.y
		+ texture(rock_color, p.xy).rgb * weights.z;
	float detail = dot(scan / mean, vec3(0.2126, 0.7152, 0.0722));
	return color * mix(1.0, clamp(detail, 0.4, 1.7), rock_texture_strength);
}

vec3 rock_relief(vec3 point, vec3 view_normal, mat4 view, mat4 inv_view) {
	if (rock_texture_strength <= 0.0) {
		return view_normal;
	}
	vec3 n = normalize((inv_view * vec4(view_normal, 0.0)).xyz);
	vec3 p = point / rock_tile;
	vec3 weights = rock_weights(n);
	vec2 x = texture(rock_normal, p.zy).xy * 2.0 - 1.0;
	vec2 y = texture(rock_normal, p.xz).xy * 2.0 - 1.0;
	vec2 z = texture(rock_normal, p.xy).xy * 2.0 - 1.0;
	vec3 slope = vec3(0.0, x.y, x.x) * weights.x
		+ vec3(y.x, 0.0, y.y) * weights.y + vec3(z.x, z.y, 0.0) * weights.z;
	slope -= n * dot(slope, n);
	return normalize((view * vec4(normalize(n + slope * rock_texture_strength * .65), 0.0)).xyz);
}
