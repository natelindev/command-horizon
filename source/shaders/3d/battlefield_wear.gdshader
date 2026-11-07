shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, fog_disabled;
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
	// Alpha-composited black attenuates the existing terrain without a lit
	// multiply pass affecting clean ground in Compatibility. It cannot glow.
	ALBEDO = vec3(0.0);
	ALPHA = mark.a * 0.75;
}
