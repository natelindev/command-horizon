shader_type spatial;
render_mode cull_back;

// Shared per-surface finish, with signed travel owned by each belt instance.
instance uniform float track_travel = 0.0;
uniform vec4 base_color : source_color = vec4(.09, .11, .12, 1.0);
uniform float metalness = .45;
uniform float base_roughness = .8;

vec3 loop_pose(float distance, float half_length, float radius, float height) {
	float straight = half_length * 2.0;
	float arc = PI * radius;
	float s = mod(distance, straight * 2.0 + arc * 2.0);
	if (s < straight) { return vec3(-half_length + s, height + radius, 0.0); }
	s -= straight;
	if (s < arc) {
		float a = PI * .5 - s / radius;
		return vec3(half_length + radius * cos(a), height + radius * sin(a), a - PI * .5);
	}
	s -= arc;
	if (s < straight) { return vec3(half_length - s, height - radius, -PI); }
	float a = -PI * .5 - (s - straight) / radius;
	return vec3(-half_length + radius * cos(a), height + radius * sin(a), a - PI * .5);
}

void vertex() {
	// glTF flips Blender's V coordinate on export.
	float half_length = 1.0 - UV.y;
	float radius = UV2.x;
	float height = 1.0 - UV2.y;
	vec3 old_pose = loop_pose(UV.x, half_length, radius, height);
	vec3 new_pose = loop_pose(UV.x + track_travel, half_length, radius, height);
	float angle = new_pose.z - old_pose.z;
	mat3 spin = mat3(vec3(1,0,0), vec3(0,cos(angle),sin(angle)), vec3(0,-sin(angle),cos(angle)));
	VERTEX = vec3(VERTEX.x, new_pose.y, -new_pose.x) + spin * vec3(0, VERTEX.y-old_pose.y, VERTEX.z+old_pose.x);
	NORMAL = spin * NORMAL;
}

void fragment() {
	ALBEDO = base_color.rgb * COLOR.rgb;
	METALLIC = metalness;
	ROUGHNESS = base_roughness;
}
