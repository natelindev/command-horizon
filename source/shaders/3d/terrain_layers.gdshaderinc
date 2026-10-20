// Scanned ground layers that modulate a ground shader's authored colors.
// Each layer is normalized by its own mean color (its smallest mip), so map
// palettes, biome grading and minimap tones keep their averages while gaining
// visible detail. Detail is projected in world XZ metres and converted to a
// world-space normal, so sloped backdrop meshes need no tangents or UVs.
uniform sampler2D base_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_tile = 15.0;
uniform float base_strength = 0.85;
uniform sampler2D path_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float path_tile = 25.0;
uniform float path_strength = 0.85;
uniform sampler2D accent_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D accent_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D accent_data : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float accent_tile = 20.0;
uniform float accent_strength = 0.85;
// 0 leaves the authored shader untouched; used by previews as a control.
uniform float terrain_detail : hint_range(0.0, 1.0) = 1.0;
// The "Ground detail" graphics setting (project shader global); 0 skips all sampling.
global uniform float ground_detail;
// Share of each scan's own hue variation kept on top of its luminance detail.
uniform float terrain_chroma : hint_range(0.0, 1.0) = 0.45;
uniform float terrain_bump = 0.8;

struct TerrainLayer {
	vec3 detail;
	vec2 slope;
	float roughness;
	float height;
	float occlusion;
};

struct TerrainSurface {
	vec3 albedo;
	vec2 slope;
	float roughness;
	float occlusion;
};

float terrain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

float terrain_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(terrain_hash(cell), terrain_hash(cell + vec2(1, 0)), t.x),
		mix(terrain_hash(cell + vec2(0, 1)), terrain_hash(cell + vec2(1, 1)), t.x), t.y);
}

// Unpacks an OpenGL normal sample into a UV-space slope (u right, v down the image).
vec2 terrain_slope(vec4 sample) {
	return vec2(sample.x, -sample.y) * 2.0 - vec2(1.0, -1.0);
}

TerrainLayer terrain_layer(sampler2D color_map, sampler2D normal_map, sampler2D data_map,
		float tile, float strength, vec2 p, vec2 dpdx, vec2 dpdy) {
	// A second, rotated and offset projection fades in over tile-sized patches so
	// repeats do not line up; the variance-preserving mix keeps contrast intact.
	// Explicit gradients keep sampling valid inside the branches that skip a
	// projection whose weight is zero.
	const float turn = 2.39996;
	mat2 rotation = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
	vec2 uv = vec2(p.x, -p.y) / tile;
	vec2 ddx = vec2(dpdx.x, -dpdx.y) / tile;
	vec2 ddy = vec2(dpdy.x, -dpdy.y) / tile;
	float w = smoothstep(0.3, 0.7, terrain_noise(p / tile * 1.4 + vec2(17.0, 5.0)));
	float k = inversesqrt(w * w + (1.0 - w) * (1.0 - w));
	vec3 mean = max(textureLod(color_map, vec2(0.5), 12.0).rgb, vec3(0.02));
	vec3 color = mean;
	vec2 slope = vec2(0.0);
	vec4 data = vec4(0.0);
	if (w < 1.0) {
		color += (textureGrad(color_map, uv, ddx, ddy).rgb - mean) * (1.0 - w) * k;
		slope += terrain_slope(textureGrad(normal_map, uv, ddx, ddy)) * (1.0 - w);
		data += textureGrad(data_map, uv, ddx, ddy) * (1.0 - w);
	}
	if (w > 0.0) {
		vec2 turned = rotation * uv * 0.83 + vec2(0.37, 0.61);
		vec2 tdx = rotation * ddx * 0.83;
		vec2 tdy = rotation * ddy * 0.83;
		color += (textureGrad(color_map, turned, tdx, tdy).rgb - mean) * w * k;
		slope += transpose(rotation) * terrain_slope(textureGrad(normal_map, turned, tdx, tdy)) * w;
		data += textureGrad(data_map, turned, tdx, tdy) * w;
	}
	vec3 ratio = max(color, vec3(0.0)) / mean;
	float luminance = dot(ratio, vec3(0.2126, 0.7152, 0.0722));
	vec3 detail = clamp(mix(vec3(luminance), ratio, terrain_chroma), vec3(0.35), vec3(1.9));
	float amount = strength * terrain_detail * ground_detail;
	TerrainLayer layer;
	layer.detail = mix(vec3(1.0), detail, amount);
	layer.slope = slope * amount;
	layer.roughness = data.r;
	layer.height = data.g;
	layer.occlusion = mix(1.0, data.b, amount);
	return layer;
}

// Height-aware transition: the incoming layer fills the lower areas of the one
// it covers first, so edges follow pebbles and cracks instead of a soft fade.
// Heights only reshape the middle of a transition; broad procedural gradients
// stay soft instead of snapping to the noise lattice.
// With heights in 0..1 the incoming weight is exactly zero for masks below this.
const float TERRAIN_BLEND_START = 0.175;

float terrain_blend(float mask, float under, float over) {
	float m = clamp(mask, 0.0, 1.0);
	float a = under * 0.35 + 1.0 - m;
	float b = over * 0.35 + m;
	float top = max(a, b) - 0.3;
	float wa = max(a - top, 0.0);
	float wb = max(b - top, 0.0);
	return wb / max(wa + wb, 0.0001);
}

TerrainLayer terrain_mix(TerrainLayer a, TerrainLayer b, float w) {
	TerrainLayer result;
	result.detail = mix(a.detail, b.detail, w);
	result.slope = mix(a.slope, b.slope, w);
	result.roughness = mix(a.roughness, b.roughness, w);
	result.height = mix(a.height, b.height, w);
	result.occlusion = mix(a.occlusion, b.occlusion, w);
	return result;
}

// `color` is the shader's authored result. `path` and `accent_weight` are the 0..1
// masks it already uses for roads/tracks and its biome feature (snow, salt...).
// Returns the authored color with scanned detail and the blended mask weights.
// Keep the weight distinct from authored_terrain's vec4 `accent` uniform.
TerrainSurface terrain_surface(vec2 p, vec3 color, float path, float accent_weight, float roughness) {
	TerrainSurface result;
	if (terrain_detail * ground_detail <= 0.0) {
		// Uniform branch: identical to the authored procedural ground and its cost.
		result.albedo = color;
		result.slope = vec2(0.0);
		result.roughness = roughness;
		result.occlusion = 1.0;
		return result;
	}
	// Derivatives are taken here, in uniform control flow, for every layer.
	vec2 dpdx = dFdx(p);
	vec2 dpdy = dFdy(p);
	TerrainLayer layer = terrain_layer(base_color, base_normal, base_data, base_tile,
		base_strength, p, dpdx, dpdy);
	// terrain_blend() is exactly zero up to TERRAIN_BLEND_START, so most ground never
	// samples the accent or path scans.
	if (accent_weight > TERRAIN_BLEND_START) {
		TerrainLayer over = terrain_layer(accent_color, accent_normal, accent_data,
			accent_tile, accent_strength, p, dpdx, dpdy);
		layer = terrain_mix(layer, over, terrain_blend(accent_weight, layer.height, over.height));
	}
	if (path > TERRAIN_BLEND_START) {
		TerrainLayer over = terrain_layer(path_color, path_normal, path_data, path_tile,
			path_strength, p, dpdx, dpdy);
		layer = terrain_mix(layer, over, terrain_blend(path, layer.height, over.height));
	}
	// Locals avoid names such as `surface` that including shaders use as uniforms.
	result.albedo = color * layer.detail;
	result.slope = layer.slope * terrain_bump;
	result.roughness = clamp(
		mix(roughness, layer.roughness, 0.45 * terrain_detail * ground_detail), 0.35, 1.0);
	result.occlusion = layer.occlusion;
	return result;
}

// Converts the detail slope to a view-space NORMAL around the mesh normal.
// UV u follows world +X and v follows world -Z.
vec3 terrain_normal(TerrainSurface ground, vec3 view_normal, mat4 view, mat4 inv_view) {
	vec3 geometric = normalize((inv_view * vec4(view_normal, 0.0)).xyz);
	vec3 world = normalize(geometric + vec3(ground.slope.x, 0.0, -ground.slope.y));
	return normalize((view * vec4(world, 0.0)).xyz);
}
