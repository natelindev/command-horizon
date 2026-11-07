shader_type spatial;
render_mode cull_back, depth_draw_never;
uniform vec4 base_color : source_color = vec4(0.5, 0.6, 0.65, 1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform bool has_texture = false;
uniform float base_metallic = 0.0;
uniform float base_roughness = 0.6;
uniform vec3 base_emission = vec3(0.0);
uniform float concealment = 0.0;
uniform float phase = 0.0;
uniform bool steady = false;
varying vec3 world;

void vertex() { world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec4 base = base_color * (has_texture ? texture(base_texture, UV) : vec4(1.0));
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float scan = pow(0.5 + 0.5 * sin(world.y * 55.0 - (steady ? 0.0 : phase * 3.0)), 8.0);
	// A stable pixel screen door complements alpha without screen-texture reads.
	float dither = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0);
	float glass = (0.1 + rim * 0.2 + scan * 0.1) * mix(0.75, 1.0, dither);
	ALBEDO = mix(base.rgb, vec3(0.25, 0.7, 0.8), concealment * 0.7);
	METALLIC = mix(base_metallic, 0.35, concealment);
	ROUGHNESS = mix(base_roughness, 0.15, concealment);
	EMISSION = mix(base_emission, vec3(0.08, 0.35, 0.42) * (rim + scan * 0.3), concealment);
	ALPHA = mix(base.a, glass, concealment);
}
