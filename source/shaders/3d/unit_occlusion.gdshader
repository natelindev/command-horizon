shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_back, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 silhouette_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
// Greater than the unit's own depth, so limbs behind its hull do not light up.
uniform float occlusion_bias = 1.0;

void vertex() {
}

void fragment() {
	float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	if (CLIP_SPACE_FAR == -1.0) {
		ndc.z = depth * 2.0 - 1.0;
	}
	vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float separation = scene.z / scene.w - VERTEX.z;
	if (separation <= occlusion_bias) {
		discard;
	}
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = silhouette_color.rgb;
	ALPHA = mix(0.18, 0.6, rim) * silhouette_color.a;
}
