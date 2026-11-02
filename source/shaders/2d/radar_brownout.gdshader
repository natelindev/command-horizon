shader_type canvas_item;

uniform bool reduced_motion = false;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float phase = reduced_motion ? 0.0 : floor(TIME * 8.0);
	float grain = noise(floor(UV * vec2(160.0, 120.0)) + phase);
	float scan = step(0.82, fract(UV.y * 50.0 + phase * 0.043));
	COLOR = vec4(vec3(0.18, 0.30, 0.32) * grain, 0.18 + grain * 0.15 + scan * 0.24);
}
