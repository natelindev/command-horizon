uniform float particle_clock = 0.0;
uniform float particle_lifetime = 1.0;
uniform vec3 gravity = vec3(0.0);
uniform float damping = 0.0;
uniform bool grounded = false;

vec3 particle_position(vec3 origin, vec3 velocity, float seconds, float floor_height) {
	float drag = max(damping, 0.0001);
	float decay = exp(-drag * seconds);
	vec3 position = origin + velocity * (1.0 - decay) / drag
		+ gravity * (seconds / drag - (1.0 - decay) / (drag * drag));
	if (damping < 0.0001) {
		position = origin + velocity * seconds + gravity * seconds * seconds * 0.5;
	}
	if (grounded) {
		position.y = max(position.y, floor_height + 0.06);
	}
	return position;
}
