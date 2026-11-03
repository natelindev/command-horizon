shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

// Soft contact occlusion shadow to firmly ground mobile units on terrain.
uniform float opacity : hint_range(0.0, 1.0) = 0.54;

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	// Tight dark core under the chassis + soft penumbra falloff
	float core = 1.0 - smoothstep(0.0, 0.62, d);
	float penumbra = 1.0 - smoothstep(0.35, 1.0, d);
	float shadow = core * 0.58 + penumbra * 0.42;
	ALBEDO = vec3(0.012, 0.010, 0.008);
	ALPHA = shadow * opacity;
}
