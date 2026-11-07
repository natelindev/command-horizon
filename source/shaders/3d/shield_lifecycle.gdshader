shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float progress = 0.0;
uniform int mode = 1;
varying vec3 shell;

void vertex() {
	shell = VERTEX;
	if (mode == 1) {
		VERTEX *= 1.0 + progress * progress * 0.32;
		VERTEX.y -= progress * progress * 0.35;
	}
}

void fragment() {
	vec2 uv = vec2(atan(shell.z, shell.x) * 1.8, shell.y * 5.5);
	vec2 cell_scale = vec2(1.0, 1.73205);
	vec2 a = mod(uv, cell_scale) - cell_scale * 0.5;
	vec2 b = mod(uv - cell_scale * 0.5, cell_scale) - cell_scale * 0.5;
	vec2 cell = dot(a, a) < dot(b, b) ? a : b;
	float edge = max(abs(cell.x), dot(abs(cell), vec2(0.5, 0.866025)));
	float lattice = smoothstep(0.37, 0.45, edge);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	float alpha;
	if (mode == 1) {
		vec2 id = uv - cell;
		float shard = fract(sin(dot(id, vec2(12.98, 78.23))) * 4375.85);
		float remain = step(progress * 0.95, shard);
		alpha = (0.10 + lattice * 0.48 + rim * 0.2) * remain * fade;
	} else if (mode == 2) {
		float sweep = exp(-pow((shell.y - mix(-1.25, 1.3, progress)) * 6.0, 2.0));
		alpha = sweep * (0.22 + rim * 0.45 + lattice * 0.18) * fade;
	} else {
		alpha = (rim * 0.28 + lattice * 0.1) * sin(progress * 3.14159) * fade;
	}
	ALBEDO = vec3(0.25, 0.8, 0.95);
	EMISSION = vec3(0.18, 0.62, 0.85) * alpha;
	ALPHA = alpha;
}
