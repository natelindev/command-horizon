#[compute]
#version 450

#include "rigid_interpolation.gdshaderinc"

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;
layout(set = 0, binding = 0) uniform sampler2D old_poses;
layout(set = 0, binding = 1) uniform sampler2D new_poses;
layout(rgba32f, set = 0, binding = 2) uniform writeonly image2D rendered_poses;
layout(push_constant, std430) uniform Params { float fraction; float rows; float pad0; float pad1; } params;

void main() {
	int row = int(gl_GlobalInvocationID.x);
	if (row >= int(params.rows)) return;
	vec4 a0 = texelFetch(old_poses, ivec2(0, row), 0);
	vec4 a1 = texelFetch(old_poses, ivec2(1, row), 0);
	vec4 a2 = texelFetch(old_poses, ivec2(2, row), 0);
	vec4 b0 = texelFetch(new_poses, ivec2(0, row), 0);
	vec4 b1 = texelFetch(new_poses, ivec2(1, row), 0);
	vec4 b2 = texelFetch(new_poses, ivec2(2, row), 0);
	mat3 basis = rigid_mix(transpose(mat3(a0.xyz, a1.xyz, a2.xyz)), transpose(mat3(b0.xyz, b1.xyz, b2.xyz)), params.fraction);
	vec3 origin = mix(vec3(a0.w, a1.w, a2.w), vec3(b0.w, b1.w, b2.w), params.fraction);
	imageStore(rendered_poses, ivec2(0, row), vec4(basis[0].x, basis[1].x, basis[2].x, origin.x));
	imageStore(rendered_poses, ivec2(1, row), vec4(basis[0].y, basis[1].y, basis[2].y, origin.y));
	imageStore(rendered_poses, ivec2(2, row), vec4(basis[0].z, basis[1].z, basis[2].z, origin.z));
	imageStore(rendered_poses, ivec2(3, row), texelFetch(new_poses, ivec2(3, row), 0));
}
