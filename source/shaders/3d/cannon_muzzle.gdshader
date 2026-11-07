shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
#include "res://source/shaders/3d/muzzle_envelope.gdshaderinc"

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 envelope = muzzle_envelope(p);
	float ring = envelope.x;
	float core = envelope.y;
	float fade = envelope.z;
	vec2 offset = p / max(r, 0.001) * (ring + core * .12) * fade * .005;
	ALBEDO = textureLod(screen_texture, clamp(SCREEN_UV + offset, vec2(.001), vec2(.999)), 0.0).rgb;
	ALBEDO += vec3(.06, .04, .015) * ring * fade;
	ALPHA = (ring * .6 + core * .18) * fade;
}
