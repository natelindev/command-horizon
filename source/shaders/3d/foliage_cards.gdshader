shader_type spatial;
render_mode cull_disabled;

uniform sampler2D leaf_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 base_color : source_color = vec4(0.2, 0.3, 0.1, 1.0);
uniform float object_detail = 1.0;

#include "res://source/shaders/3d/foliage_response.gdshaderinc"

// The shared rigid-batch builder injects pose/material setup at this hook.
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float local_height = max(VERTEX.y, 0.0) * length(MODEL_MATRIX[1].xyz);
	vec3 push = foliage_push(world, foliage_impulse_0, foliage_strengths.x)
		+ foliage_push(world, foliage_impulse_1, foliage_strengths.y)
		+ foliage_push(world, foliage_impulse_2, foliage_strengths.z)
		+ foliage_push(world, foliage_impulse_3, foliage_strengths.w)
		+ foliage_wind(world, local_height);
	VERTEX += inverse(mat3(MODEL_MATRIX)) * push;
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
