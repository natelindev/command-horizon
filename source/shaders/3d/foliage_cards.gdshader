shader_type spatial;
render_mode cull_disabled;

uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 base_color : source_color = vec4(0.2, 0.3, 0.1, 1.0);
uniform float object_detail = 1.0;

// The shared rigid-batch builder injects pose/material setup at this hook.
void vertex() {
}

void fragment() {
	vec4 leaf = texture(leaf_texture, UV);
	// Alpha-scissor keeps foliage in the depth/shadow pass, with no sorting.
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	float detail = clamp(dot(leaf.rgb, vec3(0.2126, 0.7152, 0.0722)) / 0.45, 0.55, 1.35);
	ALBEDO = base_color.rgb * mix(1.0, detail, object_detail);
	NORMAL = normalize(NORMAL) * (FRONT_FACING ? 1.0 : -1.0);
	ROUGHNESS = 0.9;
	SPECULAR = 0.18;
	BACKLIGHT = base_color.rgb * 0.22;
}
