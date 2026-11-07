uniform float progress = 0.0;

// A brief pressure front spreads rapidly, then softens as the hot core cools.
vec3 muzzle_envelope(vec2 p) {
	float age = clamp(progress, 0.0, 1.0);
	float r = length(p);
	float angle = r > 0.0001 ? atan(p.y, p.x) : 0.0;
	float expansion = 1.0 - pow(1.0 - age, 2.6);
	float radius = mix(0.05, 0.94, expansion) * (1.0 + 0.035 * cos(angle * 3.0));
	float ring = exp(-pow((r - radius) / mix(0.035, 0.11, age), 2.0));
	float core = exp(-r * r * 16.0) * (1.0 - smoothstep(0.0, 0.4, age));
	return vec3(ring, core, pow(1.0 - age, 1.8));
}
