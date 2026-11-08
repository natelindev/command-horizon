shader_type spatial;
render_mode unshaded;

uniform vec4 tint : source_color = vec4(1.0);
uniform float charge = 0.0;
uniform float phase = 0.0;

void vertex() {
	// Each immutable instance basis points its local +Z toward its spawn direction.
	// An explicit integrated clock preserves tactical pause and smooth charge ramps.
	// Derive the offset here: Compatibility packs custom data into half floats.
	float index = float(INSTANCE_ID);
	float travel = fract(phase + index * 0.618034);
	float radius = 0.07 + (1.0 - travel) * (1.0 - travel) * 0.95;
	float activation = index < 8.0 ? 1.0 : smoothstep(0.0, 1.0, charge * 16.0 - (index - 8.0));
	float envelope = sin(travel * PI);
	float size = envelope * envelope * (0.65 + charge * 0.55) * activation;
	VERTEX *= size;
	VERTEX.z += radius;
}

void fragment() {
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 1.5;
}
