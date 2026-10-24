shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float wave = exp(-pow((radius - mix(0.08, 0.94, progress)) / 0.045, 2.0));
	float fade = pow(1.0 - progress, 1.7);
	vec2 offset = p / max(radius, 0.001) * wave * fade * 0.012;
	ALBEDO = textureLod(screen_texture, clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999)), 0.0).rgb;
	ALBEDO += vec3(0.05, 0.038, 0.02) * fade;
	ALPHA = wave * fade * 0.55;
}
