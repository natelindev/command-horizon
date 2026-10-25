shader_type spatial;

// Vertex alpha marks only the luminous tracer, shell base, or motor throat.
// It is an emission mask, not transparency; bodies and fins remain solid.
void fragment() {
	ALBEDO = COLOR.rgb;
	METALLIC = 0.45 * (1.0 - COLOR.a);
	ROUGHNESS = 0.48;
	EMISSION = COLOR.rgb * COLOR.a * 3.0;
}
