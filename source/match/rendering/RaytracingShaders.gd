# gdlint: disable=max-line-length,max-file-lines
extends RefCounted

## GLSL shader sources for Vulkan Hardware Ray Tracing (RTGI + RT Reflections +
## Water RT Reflections) and spatiotemporal denoising/compositing in Godot 4.7 Forward+.

# Shared Uniform Buffer Object (std140) layout for all RT & compute passes:
# mat4 inv_view;            // 0
# mat4 inv_proj;            // 64
# mat4 view_proj;           // 128
# mat4 prev_view_proj;      // 192
# vec4 sun_dir_energy;      // 256  xyz=dir toward sun, w=sun_energy
# vec4 sun_color_daylight;  // 272  rgb=linear sun color, w=daylight
# vec4 sky_top_ambient;     // 288  rgb=linear sky top, w=ambient_energy
# vec4 sky_horizon_cloud;   // 304  rgb=linear sky horizon, w=cloud_cover
# vec4 ground_color_night;  // 320  rgb=linear ground bounce, w=night (1-daylight)
# vec4 flags0;              // 336  x=rt_gi_on, y=rt_refl_on, z=has_water, w=gi_rays
# vec4 params0;             // 352  x=gi_strength, y=rtao_strength, z=refl_strength, w=frame_index
# ivec4 dims;               // 368  x=full_w, y=full_h, z=rt_w, w=rt_h
# vec4 flags1;              // 384  x=is_ortho, y=reset_history, z=msaa_post_transparent, w=has_env_rt

const UBO_DECL = """
layout(set = 0, binding = 0, std140) uniform RTParams {
	mat4 inv_view;
	mat4 inv_proj;
	mat4 view_proj;
	mat4 prev_view_proj;
	vec4 sun_dir_energy;
	vec4 sun_color_daylight;
	vec4 sky_top_ambient;
	vec4 sky_horizon_cloud;
	vec4 ground_color_night;
	vec4 flags0;
	vec4 params0;
	ivec4 dims;
	vec4 flags1;
} u;
"""

const RAYGEN = (
	"""#version 460
#extension GL_EXT_ray_tracing : require

"""
	+ UBO_DECL
	+ """
layout(set = 0, binding = 1) uniform accelerationStructureEXT topLevelAS;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;
layout(set = 0, binding = 3) uniform sampler2D normal_roughness_tex;
layout(set = 0, binding = 4) uniform sampler2D color_tex;
layout(set = 0, binding = 5, rgba16f) uniform writeonly image2D out_gi_raw;
layout(set = 0, binding = 6, rgba16f) uniform writeonly image2D out_refl_raw;
layout(set = 0, binding = 7, rgba16f) uniform writeonly image2D out_water_refl;
layout(set = 0, binding = 8, rgba32f) uniform writeonly image2D out_cur_normal_depth;

struct RTInstance {
	vec4 albedo_roughness;
	vec4 emission_metallic;
	uvec4 meta; // x=mesh_id, y=flags
};

struct MeshDesc {
	uint index_offset;
	uint vertex_offset;
	uint index_count;
	uint pad;
};

layout(set = 0, binding = 9, std430) readonly buffer InstanceBuf { RTInstance instances[]; };
layout(set = 0, binding = 10, std430) readonly buffer MeshDescBuf { MeshDesc meshes[]; };
layout(set = 0, binding = 11, std430) readonly buffer GeoIndexBuf { uint indices[]; };
layout(set = 0, binding = 12, std430) readonly buffer GeoNormalBuf { vec4 normals[]; };

struct HitPayload {
	vec4 meta;  // x=hit_t (<0 on miss), y=uintBitsToFloat(inst_id), z=uintBitsToFloat(prim_id), w=0
	vec4 o2w_0; // xyz=objToWorld col0, w=bary.x
	vec4 o2w_1; // xyz=objToWorld col1, w=bary.y
	vec4 o2w_2; // xyz=objToWorld col2, w=0
};

layout(location = 0) rayPayloadEXT HitPayload hit_p;
layout(location = 1) rayPayloadEXT float shadow_vis;

const float PI = 3.14159265359;

uint hash_u32(uint x) {
	x ^= x >> 16;
	x *= 0x7feb352du;
	x ^= x >> 15;
	x *= 0x846ca68bu;
	x ^= x >> 16;
	return x;
}

vec2 rand2(uvec2 px, uint frame, uint sample_idx) {
	uint seed = hash_u32(px.x * 1973u ^ px.y * 9277u ^ (frame * 26699u + sample_idx * 48271u));
	float r1 = float(seed & 0x00FFFFFFu) / float(0x01000000u);
	seed = hash_u32(seed + 17u);
	float r2 = float(seed & 0x00FFFFFFu) / float(0x01000000u);
	return vec2(r1, r2);
}

void build_basis(vec3 n, out vec3 t, out vec3 b) {
	vec3 up = abs(n.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	t = normalize(cross(up, n));
	b = cross(n, t);
}

vec3 sample_cosine_hemisphere(vec3 n, vec2 xi) {
	float phi = 2.0 * PI * xi.x;
	float cos_theta = sqrt(clamp(1.0 - xi.y, 0.0, 1.0));
	float sin_theta = sqrt(clamp(xi.y, 0.0, 1.0));
	vec3 t, b;
	build_basis(n, t, b);
	return normalize(t * (cos(phi) * sin_theta) + b * (sin(phi) * sin_theta) + n * cos_theta);
}

vec3 sample_ggx_half(vec3 n, float rough, vec2 xi) {
	float a = max(rough * rough, 0.004);
	float phi = 2.0 * PI * xi.x;
	float cos_theta = sqrt(clamp((1.0 - xi.y) / (1.0 + (a * a - 1.0) * xi.y), 0.0, 1.0));
	float sin_theta = sqrt(max(0.0, 1.0 - cos_theta * cos_theta));
	vec3 t, b;
	build_basis(n, t, b);
	return normalize(t * (cos(phi) * sin_theta) + b * (sin(phi) * sin_theta) + n * cos_theta);
}

vec3 reconstruct_world(vec2 uv, float depth) {
	vec4 ndc = vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec4 view_p = u.inv_proj * ndc;
	view_p.xyz /= view_p.w;
	return (u.inv_view * vec4(view_p.xyz, 1.0)).xyz;
}

vec3 eval_sky(vec3 dir) {
	float up = clamp(dir.y, 0.0, 1.0);
	float down = clamp(-dir.y, 0.0, 1.0);
	vec3 sky = mix(u.sky_horizon_cloud.rgb, u.sky_top_ambient.rgb, pow(up, 0.55));
	sky = mix(sky, u.ground_color_night.rgb * 0.45, pow(down, 0.5));
	vec3 sun_d = normalize(u.sun_dir_energy.xyz);
	float sun_dot = max(dot(normalize(dir), sun_d), 0.0);
	float halo = pow(sun_dot, 16.0) * 0.25 * (1.0 - u.sky_horizon_cloud.w * 0.65);
	float disc = smoothstep(0.9975, 0.9994, sun_dot) * 2.8 * (1.0 - u.sky_horizon_cloud.w * 0.85);
	sky += u.sun_color_daylight.rgb * (halo + disc) * u.sun_dir_energy.w;
	return max(sky, vec3(0.0));
}

// Hybrid Screen-Space Radiance Reuse + Hardware Shadow Ray World-Space Shading
vec3 shade_hit(HitPayload p, vec3 ray_o, vec3 ray_d, vec3 cam_fwd, bool is_reflection) {
	float hit_t = p.meta.x;
	if (hit_t < 0.0) {
		return eval_sky(ray_d);
	}
	vec3 hit_pos = ray_o + ray_d * hit_t;
	uint inst_id = floatBitsToUint(p.meta.y);
	uint prim_id = floatBitsToUint(p.meta.z);
	RTInstance inst = instances[inst_id];
	MeshDesc md = meshes[inst.meta.x];
	uint base_idx = md.index_offset + prim_id * 3u;
	uint i0 = md.vertex_offset + indices[base_idx];
	uint i1 = md.vertex_offset + indices[base_idx + 1u];
	uint i2 = md.vertex_offset + indices[base_idx + 2u];
	vec3 bary = vec3(1.0 - p.o2w_0.w - p.o2w_1.w, p.o2w_0.w, p.o2w_1.w);
	vec3 n_obj = normalize(normals[i0].xyz * bary.x + normals[i1].xyz * bary.y + normals[i2].xyz * bary.z);
	mat3 o2w = mat3(p.o2w_0.xyz, p.o2w_1.xyz, p.o2w_2.xyz);
	vec3 hit_n = normalize(o2w * n_obj);
	if (dot(hit_n, ray_d) > 0.0) {
		hit_n = -hit_n;
	}

	// 1. Check if the hit point is visible in the live Forward+ HDR color buffer
	//    (gives full scanned textures, decals, explosions, dynamic area lights & multi-bounce!)
	vec4 clip = u.view_proj * vec4(hit_pos, 1.0);
	if (clip.w > 0.0001) {
		vec3 ndc = clip.xyz / clip.w;
		vec2 suv = ndc.xy * 0.5 + 0.5;
		if (suv.x > 0.01 && suv.x < 0.99 && suv.y > 0.01 && suv.y < 0.99 && ndc.z > 0.0001 && ndc.z < 0.9999) {
			float scene_d = textureLod(depth_tex, suv, 0.0).r;
			if (scene_d > 0.00001) {
				vec3 scene_pos = reconstruct_world(suv, scene_d);
				float dist_err = length(scene_pos - hit_pos);
				float facing = dot(hit_n, -cam_fwd);
				if (dist_err < (is_reflection ? 0.55 : 0.75) && facing > -0.15) {
					vec3 screen_rad = textureLod(color_tex, suv, 0.0).rgb;
					float cap = is_reflection ? 8.0 : 3.5;
					float luma = dot(screen_rad, vec3(0.2126, 0.7152, 0.0722));
					if (luma > cap) {
						screen_rad *= cap / luma;
					}
					return max(screen_rad, vec3(0.0));
				}
			}
		}
	}

	// 2. Off-screen / back-facing / occluded hit: exact hardware shadow ray + sky fill + emission!
	vec3 sun_d = normalize(u.sun_dir_energy.xyz);
	float ndotl = max(dot(hit_n, sun_d), 0.0);
	float vis = 0.0;
	if (ndotl > 0.001 && u.sun_dir_energy.w > 0.01) {
		shadow_vis = 0.0;
		traceRayEXT(
			topLevelAS,
			gl_RayFlagsTerminateOnFirstHitEXT | gl_RayFlagsSkipClosestHitShaderEXT | gl_RayFlagsOpaqueEXT,
			0x01,
			0, 0, 1,
			hit_pos + hit_n * 0.08,
			0.02,
			sun_d,
			120.0,
			1
		);
		vis = shadow_vis;
	}
	vec3 direct = inst.albedo_roughness.rgb * u.sun_color_daylight.rgb * (u.sun_dir_energy.w * ndotl * vis);
	float hemi = clamp(hit_n.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 ambient = inst.albedo_roughness.rgb * mix(u.ground_color_night.rgb * 0.5, u.sky_horizon_cloud.rgb * 0.85 + u.sky_top_ambient.rgb * 0.35, hemi) * (u.sky_top_ambient.w * 0.85);
	vec3 emit = inst.emission_metallic.rgb;
	// LivingWorld facade windows & streetlamp lanterns glow warm at night
	if (inst.meta.y == 2u) {
		emit += vec3(1.1, 0.62, 0.24) * (0.75 * u.ground_color_night.w);
	} else if (inst.meta.y == 3u) {
		emit = vec3(3.4, 1.9, 0.72) * (0.15 + 0.85 * u.ground_color_night.w);
	}
	return max(direct + ambient + emit, vec3(0.0));
}

void main() {
	ivec2 px = ivec2(gl_LaunchIDEXT.xy);
	if (px.x >= u.dims.z || px.y >= u.dims.w) {
		return;
	}
	vec2 uv = (vec2(px) + 0.5) / vec2(u.dims.zw);
	float depth = textureLod(depth_tex, uv, 0.0).r;
	vec3 cam_fwd = normalize(-u.inv_view[2].xyz);
	uint frame = uint(u.params0.w);

	// Primary camera ray for ortho or perspective
	vec3 ray_origin;
	vec3 view_dir;
	if (u.flags1.x > 0.5) {
		vec4 near_v = u.inv_proj * vec4(uv * 2.0 - 1.0, 1.0, 1.0);
		near_v.xyz /= near_v.w;
		ray_origin = (u.inv_view * vec4(near_v.xyz, 1.0)).xyz;
		view_dir = cam_fwd;
	} else {
		ray_origin = u.inv_view[3].xyz;
		vec3 far_w = reconstruct_world(uv, 0.5);
		view_dir = normalize(far_w - ray_origin);
	}

	// Water RT Reflection pass (traces transparent authored_water mask 0x02 BEFORE opaque early-out)
	vec4 water_out = vec4(0.0);
	if (u.flags0.y > 0.5 && u.flags0.z > 0.5) {
		float max_water_t = 400.0;
		if (depth > 0.00001) {
			vec3 opq_p = reconstruct_world(uv, depth);
			max_water_t = length(opq_p - ray_origin) - 0.02;
		}
		if (max_water_t > 0.05) {
			hit_p.meta = vec4(-1.0, 0.0, 0.0, 0.0);
			traceRayEXT(
				topLevelAS,
				gl_RayFlagsOpaqueEXT,
				0x02,
				0, 0, 0,
				ray_origin,
				0.02,
				view_dir,
				max_water_t,
				0
			);
			if (hit_p.meta.x > 0.0) {
				vec3 wpos = ray_origin + view_dir * hit_p.meta.x;
				vec3 wn = vec3(0.0, 1.0, 0.0);
				vec3 rdir = normalize(reflect(view_dir, wn));
				rdir.y = max(rdir.y, 0.015);
				rdir = normalize(rdir);
				vec3 wro = wpos + vec3(0.0, 0.05, 0.0);
				hit_p.meta = vec4(-1.0, 0.0, 0.0, 0.0);
				traceRayEXT(
					topLevelAS,
					gl_RayFlagsOpaqueEXT,
					0x01,
					0, 0, 0,
					wro,
					0.03,
					rdir,
					110.0,
					0
				);
				vec3 wrefl = (hit_p.meta.x > 0.0) ? shade_hit(hit_p, wro, rdir, cam_fwd, true) : eval_sky(rdir);
				float dist_fade = (hit_p.meta.x > 0.0) ? (1.0 - smoothstep(55.0, 105.0, hit_p.meta.x)) : 0.0;
				wrefl = mix(eval_sky(rdir), wrefl, dist_fade);
				water_out = vec4(wrefl, 1.0);
			}
		}
	}
	imageStore(out_water_refl, px, water_out);

	// Sky background early-out for opaque GI & reflections
	if (depth <= 0.00001) {
		imageStore(out_gi_raw, px, vec4(0.0, 0.0, 0.0, 1.0));
		imageStore(out_refl_raw, px, vec4(0.0));
		imageStore(out_cur_normal_depth, px, vec4(0.0, 1.0, 0.0, 0.0));
		return;
	}

	vec3 world_pos = reconstruct_world(uv, depth);
	vec4 nr = textureLod(normal_roughness_tex, uv, 0.0);
	vec3 view_n = normalize(nr.rgb * 2.0 - 1.0);
	float rough = nr.a;
	if (rough > 0.5) {
		rough = 1.0 - rough;
	}
	rough = clamp(rough / (127.0 / 255.0), 0.02, 1.0);
	vec3 world_n = normalize((u.inv_view * vec4(view_n, 0.0)).xyz);
	imageStore(out_cur_normal_depth, px, vec4(world_n, depth));

	// 1. Hardware Ray-Traced Global Illumination + Ray-Traced Sky Occlusion (RTGI + RTAO)
	vec4 gi_out = vec4(0.0, 0.0, 0.0, 1.0);
	if (u.flags0.x > 0.5) {
		int ray_count = max(1, int(u.flags0.w + 0.5));
		vec3 gi_accum = vec3(0.0);
		float sky_vis_accum = 0.0;
		vec3 gi_ro = world_pos + world_n * 0.07;
		for (int i = 0; i < 4; i++) {
			if (i >= ray_count) {
				break;
			}
			vec2 xi = rand2(uvec2(px), frame, uint(i));
			vec3 gi_dir = sample_cosine_hemisphere(world_n, xi);
			hit_p.meta = vec4(-1.0, 0.0, 0.0, 0.0);
			traceRayEXT(
				topLevelAS,
				gl_RayFlagsOpaqueEXT,
				0x01,
				0, 0, 0,
				gi_ro,
				0.04,
				gi_dir,
				24.0,
				0
			);
			if (hit_p.meta.x > 0.0) {
				float d = hit_p.meta.x;
				vec3 bounce = shade_hit(hit_p, gi_ro, gi_dir, cam_fwd, false);
				float atten = 1.0 - smoothstep(14.0, 24.0, d);
				gi_accum += bounce * atten;
				sky_vis_accum += smoothstep(0.35, 6.5, d);
			} else {
				sky_vis_accum += 1.0;
			}
		}
		float inv_n = 1.0 / float(ray_count);
		gi_out = vec4(gi_accum * inv_n, clamp(sky_vis_accum * inv_n, 0.0, 1.0));
	}
	imageStore(out_gi_raw, px, gi_out);

	// 2. Hardware Ray-Traced Glossy & Mirror Reflections (RTR) on Opaque Surfaces
	vec4 refl_out = vec4(0.0);
	if (u.flags0.y > 0.5 && rough < 0.66) {
		vec2 xi = rand2(uvec2(px), frame, 11u);
		// Calm micro-bump jitter slightly on horizontal water/puddles to avoid grazing self-hits
		float flat_surf = smoothstep(0.76, 0.96, world_n.y);
		vec3 refl_n = normalize(mix(world_n, vec3(0.0, 1.0, 0.0), flat_surf * 0.52));
		vec3 h = (rough < 0.14) ? refl_n : sample_ggx_half(refl_n, rough * 0.68, xi);
		vec3 rdir = normalize(reflect(view_dir, h));
		if (flat_surf > 0.25) {
			rdir.y = max(rdir.y, 0.08 * flat_surf);
			rdir = normalize(rdir);
		} else if (dot(rdir, world_n) < 0.04) {
			rdir = normalize(reflect(view_dir, world_n));
		}
		vec3 rro = world_pos + refl_n * (0.08 + 0.08 * flat_surf);
		hit_p.meta = vec4(-1.0, 0.0, 0.0, 0.0);
		traceRayEXT(
			topLevelAS,
			gl_RayFlagsOpaqueEXT,
			0x01,
			0, 0, 0,
			rro,
			0.10,
			rdir,
			95.0,
			0
		);
		vec3 refl_rad;
		float hit_conf = 0.0;
		if (hit_p.meta.x > 0.0) {
			float hit_d = hit_p.meta.x;
			refl_rad = shade_hit(hit_p, rro, rdir, cam_fwd, true);
			float dist_fade = 1.0 - smoothstep(55.0, 92.0, hit_d);
			refl_rad = mix(eval_sky(rdir), refl_rad, dist_fade);
			hit_conf = 1.0;
		} else {
			refl_rad = eval_sky(rdir);
			hit_conf = 0.45;
		}
		refl_out = vec4(refl_rad, hit_conf);
	}
	imageStore(out_refl_raw, px, refl_out);
}
"""
)

const CLOSEST_HIT = """#version 460
#extension GL_EXT_ray_tracing : require

struct HitPayload {
	vec4 meta;
	vec4 o2w_0;
	vec4 o2w_1;
	vec4 o2w_2;
};

layout(location = 0) rayPayloadInEXT HitPayload hit_p;
hitAttributeEXT vec2 attribs;

void main() {
	hit_p.meta = vec4(gl_HitTEXT, uintBitsToFloat(gl_InstanceCustomIndexEXT), uintBitsToFloat(gl_PrimitiveID), 0.0);
	hit_p.o2w_0 = vec4(gl_ObjectToWorldEXT[0], attribs.x);
	hit_p.o2w_1 = vec4(gl_ObjectToWorldEXT[1], attribs.y);
	hit_p.o2w_2 = vec4(gl_ObjectToWorldEXT[2], 0.0);
}
"""

const MISS_SKY = """#version 460
#extension GL_EXT_ray_tracing : require

struct HitPayload {
	vec4 meta;
	vec4 o2w_0;
	vec4 o2w_1;
	vec4 o2w_2;
};

layout(location = 0) rayPayloadInEXT HitPayload hit_p;

void main() {
	hit_p.meta = vec4(-1.0, 0.0, 0.0, 0.0);
}
"""

const MISS_SHADOW = """#version 460
#extension GL_EXT_ray_tracing : require

layout(location = 1) rayPayloadInEXT float shadow_vis;

void main() {
	shadow_vis = 1.0;
}
"""

const TEMPORAL_COMPUTE = (
	"""#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

"""
	+ UBO_DECL
	+ """
layout(set = 0, binding = 1) uniform sampler2D cur_gi;
layout(set = 0, binding = 2) uniform sampler2D cur_refl;
layout(set = 0, binding = 3) uniform sampler2D prev_gi;
layout(set = 0, binding = 4) uniform sampler2D prev_refl;
layout(set = 0, binding = 5) uniform sampler2D cur_nd;
layout(set = 0, binding = 6) uniform sampler2D prev_nd;
layout(set = 0, binding = 7, rgba16f) uniform writeonly image2D out_gi_accum;
layout(set = 0, binding = 8, rgba16f) uniform writeonly image2D out_refl_accum;

vec3 reconstruct_world(vec2 uv, float depth) {
	vec4 ndc = vec4(uv * 2.0 - 1.0, depth, 1.0);
	vec4 view_p = u.inv_proj * ndc;
	view_p.xyz /= view_p.w;
	return (u.inv_view * vec4(view_p.xyz, 1.0)).xyz;
}

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= u.dims.z || px.y >= u.dims.w) {
		return;
	}
	vec2 uv = (vec2(px) + 0.5) / vec2(u.dims.zw);
	vec4 gi_now = texelFetch(cur_gi, px, 0);
	vec4 refl_now = texelFetch(cur_refl, px, 0);
	vec4 nd_now = texelFetch(cur_nd, px, 0);

	if (u.flags1.y > 0.5 || nd_now.a <= 0.00001) {
		imageStore(out_gi_accum, px, gi_now);
		imageStore(out_refl_accum, px, refl_now);
		return;
	}

	vec3 wpos = reconstruct_world(uv, nd_now.a);
	vec4 prev_clip = u.prev_view_proj * vec4(wpos, 1.0);
	vec2 prev_uv = (prev_clip.xy / max(prev_clip.w, 0.0001)) * 0.5 + 0.5;
	float prev_expected_d = prev_clip.z / max(prev_clip.w, 0.0001);

	bool valid = prev_uv.x > 0.002 && prev_uv.x < 0.998 && prev_uv.y > 0.002 && prev_uv.y < 0.998;
	if (valid) {
		vec4 prev_nd_sample = textureLod(prev_nd, prev_uv, 0.0);
		float ndot = dot(normalize(nd_now.xyz), normalize(prev_nd_sample.xyz));
		float derr = abs(prev_nd_sample.a - prev_expected_d);
		if (prev_nd_sample.a <= 0.00001 || ndot < 0.85 || derr > 0.004) {
			valid = false;
		}
	}

	if (!valid) {
		imageStore(out_gi_accum, px, gi_now);
		imageStore(out_refl_accum, px, refl_now);
		return;
	}

	// 3x3 neighborhood variance clamping prevents ghosting on moving tanks & explosions
	vec4 gi_mean = vec4(0.0);
	vec4 gi_m2 = vec4(0.0);
	vec4 refl_mean = vec4(0.0);
	vec4 refl_m2 = vec4(0.0);
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 sp = clamp(px + ivec2(dx, dy), ivec2(0), u.dims.zw - ivec2(1));
			vec4 g = texelFetch(cur_gi, sp, 0);
			vec4 r = texelFetch(cur_refl, sp, 0);
			gi_mean += g;
			gi_m2 += g * g;
			refl_mean += r;
			refl_m2 += r * r;
		}
	}
	gi_mean /= 9.0;
	vec4 gi_std = sqrt(max(gi_m2 / 9.0 - gi_mean * gi_mean, vec4(0.0001)));
	refl_mean /= 9.0;
	vec4 refl_std = sqrt(max(refl_m2 / 9.0 - refl_mean * refl_mean, vec4(0.0001)));

	vec4 gi_hist = textureLod(prev_gi, prev_uv, 0.0);
	gi_hist = clamp(gi_hist, gi_mean - gi_std * 1.5, gi_mean + gi_std * 1.5);
	vec4 refl_hist = textureLod(prev_refl, prev_uv, 0.0);
	refl_hist = clamp(refl_hist, refl_mean - refl_std * 1.35, refl_mean + refl_std * 1.35);

	imageStore(out_gi_accum, px, mix(gi_hist, gi_now, 0.14));
	imageStore(out_refl_accum, px, mix(refl_hist, refl_now, 0.22));
}
"""
)

const DENOISE_COMPUTE = (
	"""#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

"""
	+ UBO_DECL
	+ """
layout(set = 0, binding = 1) uniform sampler2D in_gi;
layout(set = 0, binding = 2) uniform sampler2D in_refl;
layout(set = 0, binding = 3) uniform sampler2D cur_nd;
layout(set = 0, binding = 4) uniform sampler2D normal_roughness_tex;
layout(set = 0, binding = 5, rgba16f) uniform writeonly image2D out_gi;
layout(set = 0, binding = 6, rgba16f) uniform writeonly image2D out_refl;

layout(push_constant, std430) uniform DenoisePush {
	int step_size;
	int pad0;
	int pad1;
	int pad2;
} pc;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= u.dims.z || px.y >= u.dims.w) {
		return;
	}
	vec4 center_nd = texelFetch(cur_nd, px, 0);
	vec4 center_gi = texelFetch(in_gi, px, 0);
	vec4 center_refl = texelFetch(in_refl, px, 0);
	if (center_nd.a <= 0.00001) {
		imageStore(out_gi, px, center_gi);
		imageStore(out_refl, px, center_refl);
		return;
	}

	vec2 uv = (vec2(px) + 0.5) / vec2(u.dims.zw);
	vec4 nr = textureLod(normal_roughness_tex, uv, 0.0);
	float rough = nr.a;
	if (rough > 0.5) {
		rough = 1.0 - rough;
	}
	rough = clamp(rough / (127.0 / 255.0), 0.02, 1.0);
	vec3 cn = normalize(center_nd.xyz);
	float cd = center_nd.a;

	const float k_w[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);
	vec4 gi_sum = center_gi;
	float gi_wsum = 1.0;
	vec4 refl_sum = center_refl;
	float refl_wsum = 1.0;
	// Keep mirror-smooth reflections crisp; allow wider denoising on glossy/rough metals
	float refl_blur_scale = smoothstep(0.06, 0.32, rough);

	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) {
				continue;
			}
			ivec2 sp = clamp(px + ivec2(dx, dy) * pc.step_size, ivec2(0), u.dims.zw - ivec2(1));
			vec4 snd = texelFetch(cur_nd, sp, 0);
			if (snd.a <= 0.00001) {
				continue;
			}
			float spatial_w = k_w[abs(dx)] * k_w[abs(dy)];
			float nw = pow(max(dot(cn, normalize(snd.xyz)), 0.0), 24.0);
			float dw = exp(-abs(cd - snd.a) * 650.0);
			float w_gi = spatial_w * nw * dw;
			gi_sum += texelFetch(in_gi, sp, 0) * w_gi;
			gi_wsum += w_gi;

			float w_refl = w_gi * refl_blur_scale;
			vec4 sr = texelFetch(in_refl, sp, 0);
			if (sr.a > 0.01 && w_refl > 0.001) {
				refl_sum += sr * w_refl;
				refl_wsum += w_refl;
			}
		}
	}
	imageStore(out_gi, px, gi_sum / max(gi_wsum, 0.0001));
	imageStore(out_refl, px, refl_sum / max(refl_wsum, 0.0001));
}
"""
)

const SNAPSHOT_COMPUTE = """#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D in_color;
layout(set = 0, binding = 1) uniform sampler2D in_depth;
layout(set = 0, binding = 2, rg32f) uniform writeonly image2D out_snap; // r=opaque_luma, g=opaque_depth (full FP32!)

layout(push_constant, std430) uniform SnapPush {
	int w;
	int h;
	int pad0;
	int pad1;
} pc;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= pc.w || px.y >= pc.h) {
		return;
	}
	vec3 c = texelFetch(in_color, px, 0).rgb;
	float d = texelFetch(in_depth, px, 0).r;
	float luma = dot(max(c, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722));
	imageStore(out_snap, px, vec4(luma, d, 0.0, 0.0));
}
"""

const COMPOSITE_COMPUTE = (
	"""#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

"""
	+ UBO_DECL
	+ """
layout(set = 0, binding = 1, rgba16f) uniform image2D color_img;
layout(set = 0, binding = 2) uniform sampler2D depth_tex;
layout(set = 0, binding = 3) uniform sampler2D normal_roughness_tex;
layout(set = 0, binding = 4) uniform sampler2D gi_tex;
layout(set = 0, binding = 5) uniform sampler2D refl_tex;
layout(set = 0, binding = 6) uniform sampler2D opaque_snap_tex;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	if (px.x >= u.dims.x || px.y >= u.dims.y) {
		return;
	}
	vec2 uv = (vec2(px) + 0.5) / vec2(u.dims.xy);
	float depth = texelFetch(depth_tex, px, 0).r;
	if (depth <= 0.00001) {
		return;
	}

	vec4 cur = imageLoad(color_img, px);
	float fog_vis = 1.0;
	if (u.flags1.z > 0.5) {
		// POST_TRANSPARENT MSAA-safe path: respect FogOfWar and skip transparent authored_water
		vec2 snap = texelFetch(opaque_snap_tex, px, 0).rg;
		float opq_luma = snap.r;
		float opq_depth = snap.g;
		// authored_water uses depth_draw_always -> depth changed since opaque pass!
		if (abs(depth - opq_depth) > 0.00008) {
			return;
		}
		float final_luma = dot(max(cur.rgb, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722));
		// Unexplored fog of war (shroud_tint in linear space is ~0.003 luma); skip cleanly
		if (final_luma < 0.0055) {
			return;
		}
		fog_vis = clamp(final_luma / max(opq_luma, 0.006), 0.0, 1.0);
		fog_vis *= smoothstep(0.0055, 0.022, final_luma);
	}

	vec4 nr = texelFetch(normal_roughness_tex, px, 0);
	vec3 view_n = normalize(nr.rgb * 2.0 - 1.0);
	float rough = nr.a;
	if (rough > 0.5) {
		rough = 1.0 - rough;
	}
	rough = clamp(rough / (127.0 / 255.0), 0.02, 1.0);
	vec3 world_n = normalize((u.inv_view * vec4(view_n, 0.0)).xyz);

	vec3 cam_fwd = normalize(-u.inv_view[2].xyz);
	vec3 view_dir;
	if (u.flags1.x > 0.5) {
		view_dir = cam_fwd;
	} else {
		vec4 ndc = vec4(uv * 2.0 - 1.0, depth, 1.0);
		vec4 vp = u.inv_proj * ndc;
		vp.xyz /= vp.w;
		vec3 wpos = (u.inv_view * vec4(vp.xyz, 1.0)).xyz;
		view_dir = normalize(wpos - u.inv_view[3].xyz);
	}

	vec3 col = cur.rgb;

	// 1. Apply RTGI + RTAO
	if (u.flags0.x > 0.5) {
		vec4 gi = textureLod(gi_tex, uv, 0.0);
		float sky_vis = clamp(gi.a, 0.0, 1.0);
		// Apply RTAO primarily to shaded/ambient regions so direct sun stays crisp
		float cur_luma = dot(max(col, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722));
		float shadow_weight = mix(1.0, 0.36, smoothstep(0.14, 0.88, cur_luma));
		float ao_factor = mix(1.0, mix(0.38, 1.0, sky_vis), u.params0.y * shadow_weight * fog_vis);
		col *= ao_factor;

		// Add physically weighted multi-bounce diffuse indirect illumination
		vec3 surface_tint = clamp(col / max(cur_luma, 0.06), vec3(0.40), vec3(1.55));
		float surface_reflectance = mix(0.36, 0.72, clamp(cur_luma * 1.5, 0.0, 1.0));
		vec3 gi_bounce = gi.rgb * surface_tint * surface_reflectance * (u.params0.x * fog_vis);
		col += gi_bounce;
	}

	// 2. Apply Hardware Ray-Traced Opaque Reflections (water, wet puddles, metallic armor, glass)
	if (u.flags0.y > 0.5 && rough < 0.64) {
		vec4 refl = textureLod(refl_tex, uv, 0.0);
		if (refl.a > 0.01) {
			float ndotv = clamp(dot(world_n, -view_dir), 0.0, 1.0);
			float smooth_w = 1.0 - smoothstep(0.04, 0.60, rough);
			// Mirror-smooth water/puddles get bold physical reflections; matte/satin metals stay subtle
			float mirror_boost = 1.0 - smoothstep(0.06, 0.22, rough);
			float f0 = mix(0.05, 0.42, smooth_w * smooth_w);
			float fresnel = f0 + (1.0 - f0) * pow(1.0 - ndotv, 3.0);
			float blend = clamp(
				fresnel * smooth_w * mix(0.65, 1.15, mirror_boost) * u.params0.z * fog_vis,
				0.0,
				0.82
			);
			col = mix(col, max(refl.rgb, col * 0.22), blend);
		}
	}

	imageStore(color_img, px, vec4(max(col, vec3(0.0)), cur.a));
}
"""
)
