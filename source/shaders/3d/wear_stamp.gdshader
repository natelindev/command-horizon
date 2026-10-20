shader_type texture_blit;
render_mode blend_mix;
uniform float angle = 0.0;
uniform bool tracks = false;

void blit() {
	vec2 p = UV * 2.0 - 1.0;
	p = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p;
	float alpha;
	if (tracks) {
		float rails = 1.0 - smoothstep(0.10, 0.20, abs(abs(p.y) - 0.44));
		float tread = mix(0.45, 1.0, smoothstep(0.35, 0.55, fract(p.x * 7.0)));
		alpha = rails * tread * (1.0 - smoothstep(0.55, 0.95, abs(p.x))) * 0.24;
	} else {
		float rough = sin(p.x * 19.0 + sin(p.y * 15.0)) * sin(p.y * 23.0) * 0.08;
		alpha = (1.0 - smoothstep(0.1, 0.95, length(p) + rough)) * 0.52;
	}
	COLOR0 = vec4(vec3(0.07, 0.055, 0.04), alpha) * MODULATE;
}
