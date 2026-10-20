shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, fog_disabled;
uniform sampler2D wear_map : source_color, filter_linear, repeat_disable;
uniform vec2 map_size = vec2(200.0);
varying vec2 ground_uv;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_uv = world.xz / map_size;
	// Match the actual terrain surface, including authored terraces and ramps.
	VERTEX += NORMAL * 0.012;
}

void fragment() {
	vec4 mark = texture(wear_map, ground_uv);
	// Multiply the already-lit terrain: soot must never glow under a dark sky.
	ALBEDO = mix(vec3(1.0), vec3(0.25, 0.23, 0.21), mark.a);
	ALPHA = 1.0;
}
