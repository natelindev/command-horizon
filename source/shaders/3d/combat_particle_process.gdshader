shader_type particles;
render_mode disable_force, collision_use_scale;
uniform vec3 gravity = vec3(0.0);
uniform float growth_start = 1.0;
uniform float growth_end = 0.2;
uniform float damping = 0.8;
uniform bool grounded = false;
uniform bool terrain_collision = false;
uniform bool directional = false;

void start() {
	USERDATA1.x = CUSTOM.x + 0.06;
	// Per-emission seed decorrelates shape, rotation and turbulence.
	float seed = fract(sin(dot(TRANSFORM[3].xyz + VELOCITY, vec3(12.9898, 78.233, 39.425))) * 43758.5453);
	CUSTOM = vec4(0.0, COLOR.a, length(TRANSFORM[0].xyz), seed);
}

void process() {
	CUSTOM.x += DELTA / LIFETIME;
	if (CUSTOM.x >= 1.0) { ACTIVE = false; }
	VELOCITY += gravity * DELTA;
	VELOCITY *= exp(-damping * DELTA);
	if (terrain_collision && COLLIDED) {
		TRANSFORM[3].xyz += COLLISION_NORMAL * COLLISION_DEPTH;
		float normal_speed = dot(VELOCITY, COLLISION_NORMAL);
		if (normal_speed < 0.0) {
			VELOCITY -= COLLISION_NORMAL * normal_speed * 1.22;
			VELOCITY *= 0.65;
		}
	}
	if (grounded && !terrain_collision && TRANSFORM[3].y < USERDATA1.x) {
		TRANSFORM[3].y = USERDATA1.x;
		VELOCITY.y = abs(VELOCITY.y) * 0.22;
		VELOCITY.xz *= 0.65;
	}
	float size = CUSTOM.z * mix(growth_start, growth_end, CUSTOM.x);
	TRANSFORM[0].xyz = vec3(size, 0.0, 0.0);
	TRANSFORM[1].xyz = vec3(0.0, size, 0.0);
	TRANSFORM[2].xyz = vec3(0.0, 0.0, size);
	if (directional && length(VELOCITY) > 0.01) {
		TRANSFORM[0].xyz = normalize(VELOCITY) * size;
	}
	COLOR.a = CUSTOM.y * (1.0 - smoothstep(0.1, 1.0, CUSTOM.x));
}
