shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 hit_color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform float hit_strength = 0.0;

void fragment() {
	// A restrained surface emission leaves paint, team color and silhouette visible.
	ALBEDO = hit_color.rgb * hit_strength * 0.3;
	EMISSION = hit_color.rgb * hit_strength;
	ALPHA = hit_strength * 0.42;
}
