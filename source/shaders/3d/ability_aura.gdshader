shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform int mode = 0;
uniform float phase = 0.0;
uniform bool steady = false;
varying vec3 local;
void vertex() { local = VERTEX; }
void fragment() {
	float clock = steady ? 0.0 : phase;
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	float pulse = steady ? 0.65 : 0.65 + 0.35 * sin(clock * 2.5);
	vec3 color = vec3(0.15, 0.75, 0.95);
	float alpha;
	if (mode == 0) {
		vec2 grid = abs(fract(vec2(UV.x * 18.0, UV.y * 12.0 - clock * 0.15)) - 0.5);
		float lattice = smoothstep(0.45, 0.49, max(grid.x, grid.y));
		alpha = (lattice * 0.25 + rim * 0.18) * pulse;
	} else if (mode == 1) {
		float scramble = sin(local.y * 45.0 + sin(local.x * 20.0 + clock) * 2.0 - clock * 3.0);
		alpha = smoothstep(0.92, 1.0, scramble) * rim * 0.16;
		color = vec3(0.6, 0.8, 0.85);
	} else {
		color = vec3(1.0, 0.62, 0.18);
		float cap = smoothstep(0.2, 0.7, local.y);
		alpha = 0.5 + cap * 0.4;
		pulse = steady ? 0.5 : 0.55 + 0.45 * pow(max(0.0, sin(clock * 3.0)), 4.0);
		color *= mix(0.25, pulse, cap);
	}
	ALBEDO = color;
	EMISSION = color * pulse * 0.5;
	ALPHA = alpha;
}
