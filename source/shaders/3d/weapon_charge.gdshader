shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform bool lock_on = false;
uniform bool reduced_motion = false;

void vertex() {
	// Camera-facing focus, with an explicit clock so tactical pause freezes it.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	float pulse = reduced_motion ? 0.5 : 0.5 + 0.5 * sin(phase * (13.0 + charge * 15.0));
	float ink;
	float white = 0.0;
	if (lock_on) {
		// Four crisp contracting brackets, a crosshair, and a clockwise lock sweep.
		vec2 q = abs(p);
		float edge = mix(0.72, 0.38, charge);
		float bracket = max(
			(1.0 - smoothstep(0.013, 0.027, abs(q.x - edge))) * step(edge - 0.17, q.y) * step(q.y, edge + 0.02),
			(1.0 - smoothstep(0.013, 0.027, abs(q.y - edge))) * step(edge - 0.17, q.x) * step(q.x, edge + 0.02)
		);
		float crosshair = max(
			(1.0 - smoothstep(0.009, 0.018, q.x)) * step(q.y, 0.12),
			(1.0 - smoothstep(0.009, 0.018, q.y)) * step(q.x, 0.12)
		);
		float sweep = (1.0 - smoothstep(0.01, 0.023, abs(r - 0.25)))
			* step((angle + 3.141593) / 6.283185, charge);
		ink = bracket + crosshair * 0.45 + sweep * 0.8;
	} else {
		// A small hot core feeds contracting broken capacitor rings and arcing filaments.
		white = exp(-r * r / 0.009) * (0.8 + charge * 0.8 + pulse * 0.25);
		float core = exp(-r * r / 0.033) * (0.4 + charge * 0.45);
		float radius = mix(0.67, 0.42, charge);
		float ring_a = exp(-pow((r - radius) / 0.018, 2.0));
		float ring_b = exp(-pow((r - radius * 0.69) / 0.013, 2.0));
		float segments = smoothstep(-0.3, 0.2, sin(angle * 6.0 + phase * 2.8));
		float coil = ring_a * segments + ring_b * (1.0 - segments * 0.65);
		float arc_radius = radius + sin(angle * 17.0 + floor(phase * 24.0)) * 0.025
			+ sin(angle * 31.0 - phase * 9.0) * 0.014;
		float arc = exp(-pow((r - arc_radius) / 0.009, 2.0))
			* pow(max(0.0, sin(angle * 3.0 - phase * 8.0)), 6.0);
		ink = core + coil * (0.35 + charge * 0.85) + (reduced_motion ? 0.0 : arc * charge * 1.4);
	}
	float strength = reduced_motion ? 0.65 : 1.4;
	ALBEDO = tint.rgb * ink * strength + vec3(0.85, 0.95, 1.0) * white * strength;
	ALPHA = clamp(ink + white, 0.0, 1.0);
}
