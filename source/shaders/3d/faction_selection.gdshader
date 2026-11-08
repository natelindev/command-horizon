shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0);
uniform float width_pixels = 3.0;
uniform float inner_edge_width_pixels = 1.5;
uniform float outer_edge_width_pixels = 1.0;
uniform vec2 half_extents = vec2(0.0);
uniform int faction_style = 0;
instance uniform float animation_time = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float distance_to_edge = length(p) - 0.88;
	float segments = 1.0;
	bool rectangular = half_extents.x > 0.0;
	if (rectangular || faction_style == 0) {
		// Four industrial corner brackets, clear even on crowded infantry groups.
		vec2 bounds = abs(p);
		distance_to_edge = max(bounds.x, bounds.y) - 0.86;
		segments = smoothstep(0.40, 0.45, min(bounds.x, bounds.y));
	} else if (faction_style == 1) {
		// Six flat faces with a quiet travelling highlight; no rapid pulse.
		float sector = mod(angle + 0.5235988, 1.0471976) - 0.5235988;
		distance_to_edge = cos(sector) * length(p) - 0.78;
	} else {
		float dash = fract((angle + 3.1415927) / 6.2831853 * 12.0);
		segments = smoothstep(0.05, 0.12, dash) * (1.0 - smoothstep(0.72, 0.79, dash));
	}
	float pixel = max(fwidth(distance_to_edge), 0.0001);
	float thickness = clamp(width_pixels, 1.5, 3.5);
	float line = 1.0 - smoothstep(thickness * 0.35, thickness * 0.35 + 1.0, abs(distance_to_edge) / pixel);
	float highlight = 0.88 + 0.12 * cos(angle - animation_time * 0.65);

	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	if (CLIP_SPACE_FAR < 0.0) {
		ndc.z = depth * 2.0 - 1.0;
	}
	vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	behind.xyz /= behind.w;
	bool is_occluded = VERTEX.z < behind.z - 0.15;

	if (is_occluded) {
		ALBEDO = color.rgb * 1.15;
		EMISSION = color.rgb * 0.6;
		ALPHA = line * segments * color.a * 0.55;
	} else {
		ALBEDO = color.rgb * highlight;
		EMISSION = color.rgb * (faction_style == 1 ? 0.18 : 0.04);
		ALPHA = line * segments * color.a * 0.9;
	}
}
