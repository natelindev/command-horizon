shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform float heat = 0.0;
void fragment() {
	float tip = smoothstep(.0, .7, UV.y);
	float intensity = heat * heat * tip;
	ALBEDO = mix(vec3(.65,.06,.005), vec3(1.0,.35,.04), heat);
	ALPHA = intensity * .42;
}
