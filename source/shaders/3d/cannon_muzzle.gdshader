shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = exp(-pow((r - mix(0.06, 0.95, progress)) / 0.06, 2.0));
	float core = exp(-r * r * 12.0) * (1.0 - progress);
	float fade = pow(1.0 - progress, 2.0);
	vec2 shimmer = vec2(sin(p.y * 35.0 + progress * 22.0), cos(p.x * 29.0)) * core;
	vec2 offset = (p / max(r, 0.001) * ring + shimmer * .15) * fade * .008;
	ALBEDO = textureLod(screen_texture, clamp(SCREEN_UV + offset, vec2(.001), vec2(.999)), 0.0).rgb;
	ALBEDO += vec3(.06, .04, .015) * ring * fade;
	ALPHA = (ring * .6 + core * .18) * fade;
}
