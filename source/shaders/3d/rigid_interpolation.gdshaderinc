// Rigid parts interpolate on the GPU. Normalized quaternion interpolation
// preserves rotor/limb length, unlike linearly blending two basis matrices.
vec4 rigid_quaternion(mat3 m) {
	float trace = m[0][0] + m[1][1] + m[2][2];
	vec4 q;
	if (trace > 0.0) {
		float s = sqrt(trace + 1.0) * 2.0;
		q = vec4((m[1][2] - m[2][1]) / s, (m[2][0] - m[0][2]) / s, (m[0][1] - m[1][0]) / s, 0.25 * s);
	} else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) {
		float s = sqrt(1.0 + m[0][0] - m[1][1] - m[2][2]) * 2.0;
		q = vec4(0.25 * s, (m[1][0] + m[0][1]) / s, (m[2][0] + m[0][2]) / s, (m[1][2] - m[2][1]) / s);
	} else if (m[1][1] > m[2][2]) {
		float s = sqrt(1.0 + m[1][1] - m[0][0] - m[2][2]) * 2.0;
		q = vec4((m[1][0] + m[0][1]) / s, 0.25 * s, (m[2][1] + m[1][2]) / s, (m[2][0] - m[0][2]) / s);
	} else {
		float s = sqrt(1.0 + m[2][2] - m[0][0] - m[1][1]) * 2.0;
		q = vec4((m[2][0] + m[0][2]) / s, (m[2][1] + m[1][2]) / s, 0.25 * s, (m[0][1] - m[1][0]) / s);
	}
	return normalize(q);
}

mat3 rigid_basis(vec4 q) {
	vec3 q2 = q.xyz + q.xyz;
	vec3 xx = q.xyz * q2;
	vec3 xy = q.xxy * q2.yzz;
	vec3 wx = q.w * q2;
	return mat3(vec3(1.0 - xx.y - xx.z, xy.x + wx.z, xy.y - wx.y),
		vec3(xy.x - wx.z, 1.0 - xx.x - xx.z, xy.z + wx.x),
		vec3(xy.y + wx.y, xy.z - wx.x, 1.0 - xx.x - xx.y));
}

mat3 rigid_mix(mat3 a, mat3 b, float weight) {
	vec3 sa = vec3(length(a[0]), length(a[1]), length(a[2]));
	vec3 sb = vec3(length(b[0]), length(b[1]), length(b[2]));
	if (min(min(sa.x, sa.y), sa.z) < 0.00001 || min(min(sb.x, sb.y), sb.z) < 0.00001) return b;
	sa.z *= sign(determinant(a));
	sb.z *= sign(determinant(b));
	vec4 qa = rigid_quaternion(mat3(a[0] / sa.x, a[1] / sa.y, a[2] / sa.z));
	vec4 qb = rigid_quaternion(mat3(b[0] / sb.x, b[1] / sb.y, b[2] / sb.z));
	if (dot(qa, qb) < 0.0) qb = -qb;
	mat3 rotation = rigid_basis(normalize(mix(qa, qb, weight)));
	vec3 scale = mix(sa, sb, weight);
	return mat3(rotation[0] * scale.x, rotation[1] * scale.y, rotation[2] * scale.z);
}
