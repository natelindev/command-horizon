// Shared by the GPU simulation and Compatibility's analytic draw path.
uniform bool billow = false;
uniform float fade_in = 0.0;

float particle_growth(float age) {
	// Expanding gas loses pressure: fast initial growth, then a gentle coast.
	return billow ? 1.0 - pow(1.0 - clamp(age, 0.0, 1.0), 3.0) : age;
}

float particle_opacity(float age) {
	float birth = fade_in > 0.0 ? smoothstep(0.0, fade_in, age) : 1.0;
	return birth * (1.0 - smoothstep(0.1, 1.0, age));
}
