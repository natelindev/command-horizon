// Authored relief, never normals inferred from albedo. Shared between faction
// shaders; UV2 holds the optional per-part trim layout. Zero UV2 opts out.
uniform sampler2D metal_micro_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal_micro_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D trim_color : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D trim_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D trim_orm : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool trim_enabled = false;
uniform float metal_detail_strength : hint_range(0.0, 1.0) = 1.0;
uniform float micro_normal_strength = 0.10;
uniform float micro_tile = 0.22;
uniform float trim_normal_strength = 0.55;

struct MetalFinish {
	vec3 normal;
	float color;
	float occlusion;
	float roughness_delta;
	float exposure;
};

MetalFinish metal_finish(vec3 point, vec3 local_normal, mat3 to_view,
		vec3 view_position, vec3 view_normal, vec2 trim_uv) {
	MetalFinish result;
	vec3 n = normalize(local_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(dot(w, vec3(1.0)), 0.0001);
	vec3 p = point / micro_tile;
	vec2 nx = texture(metal_micro_normal, p.zy).xy * 2.0 - 1.0;
	vec2 ny = texture(metal_micro_normal, p.xz).xy * 2.0 - 1.0;
	vec2 nz = texture(metal_micro_normal, p.xy).xy * 2.0 - 1.0;
	vec3 slope = vec3(0.0, -nx.y, nx.x) * w.x
		+ vec3(ny.x, 0.0, -ny.y) * w.y + vec3(nz.x, -nz.y, 0.0) * w.z;
	slope -= n * dot(n, slope);
	vec3 data = texture(metal_micro_orm, p.zy).rgb * w.x
		+ texture(metal_micro_orm, p.xz).rgb * w.y
		+ texture(metal_micro_orm, p.xy).rgb * w.z;
	result.normal = normalize(view_normal + to_view * slope * micro_normal_strength * metal_detail_strength);
	result.roughness_delta = (data.g - 0.61) * 0.55 * metal_detail_strength;
	result.color = 1.0;
	result.occlusion = 1.0;
	result.exposure = 0.0;
	// Derivatives must be evaluated before the per-fragment trim branch.
	vec3 dx = dFdx(view_position);
	vec3 dy = dFdy(view_position);
	vec2 ux = dFdx(trim_uv);
	vec2 uy = dFdy(trim_uv);
	vec3 a = cross(dy, view_normal);
	vec3 b = cross(view_normal, dx);
	vec3 tangent = a * ux.x + b * uy.x;
	vec3 bitangent = a * ux.y + b * uy.y;
	float frame_scale = inversesqrt(max(max(dot(tangent, tangent), dot(bitangent, bitangent)), 0.00000001));
	if (trim_enabled && trim_uv.x > 0.0001 && trim_uv.y > 0.0001) {
		vec3 orm = texture(trim_orm, trim_uv).rgb;
		vec2 relief = texture(trim_normal, trim_uv).xy * 2.0 - 1.0;
		// UVs grow down the image; OpenGL normal +Y grows up it.
		vec3 perturbation = (tangent * relief.x - bitangent * relief.y) * frame_scale;
		result.normal = normalize(result.normal + perturbation * trim_normal_strength * metal_detail_strength);
		result.color = mix(1.0, texture(trim_color, trim_uv).r, metal_detail_strength);
		result.occlusion = mix(1.0, orm.r, metal_detail_strength * 0.6);
		result.roughness_delta += (orm.g - 0.6) * 0.5 * metal_detail_strength;
		result.exposure = orm.b * metal_detail_strength;
	}
	return result;
}
