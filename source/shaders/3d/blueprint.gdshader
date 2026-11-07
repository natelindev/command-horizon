shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.16, 0.85, 0.65, 1.0);
uniform float phase = 0.0;
uniform bool steady = false;
varying vec3 local;
varying vec3 world;
void vertex() {
	local = VERTEX;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float clock = steady ? 0.0 : phase;
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float scan = pow(0.5 + 0.5 * sin(world.y * 35.0 - clock * 3.0), 10.0);
	vec3 grid = abs(fract(world * 2.0) - 0.5);
	float line = smoothstep(0.46, 0.495, max(grid.x, grid.z));
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * (rim * 0.65 + scan * 0.12);
	ALPHA = (0.1 + rim * 0.4 + scan * 0.12 + line * 0.06) * tint.a;
}
