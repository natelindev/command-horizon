shader_type spatial;

#include "res://source/shaders/3d/surface_detail.gdshaderinc"
#include "res://source/shaders/3d/metal_detail.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.5);
uniform float metalness = 0.2;
uniform float base_roughness = 0.55;
varying vec3 armor_position;
varying vec3 armor_normal;
varying vec4 armor_weathering;
varying float armor_height;
varying mat3 armor_to_view;

void vertex() {
	vec3 scale = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)), vec3(0.0001));
	armor_position = VERTEX * scale;
	armor_normal = normalize(NORMAL / scale);
	armor_to_view = mat3(MODELVIEW_MATRIX[0].xyz / scale.x,
		MODELVIEW_MATRIX[1].xyz / scale.y, MODELVIEW_MATRIX[2].xyz / scale.z);
	armor_weathering = COLOR;
	armor_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	bool trimmed = trim_enabled && UV2.x > 0.0001 && UV2.y > 0.0001;
	float detail = armor_panels && !trimmed ? armor_detail(armor_position, armor_normal) : 1.0;
	MetalFinish finish = metal_finish(armor_position, armor_normal, armor_to_view, VERTEX, NORMAL, UV2);
	NORMAL = finish.normal;
	AO = finish.occlusion;
	// UV-authored plates replace the legacy projected artwork where available.
	if (trimmed) { detail = finish.color; }
	ALBEDO = weathered(ground_dust(base_color.rgb * detail, armor_height), armor_weathering, true);
	// Chipped edges expose bare steel.
	METALLIC = mix(metalness, 0.7, max((1.0 - armor_weathering.a) * 0.5, finish.exposure * 0.35));
	// Roughness follows authored paint relief and fine cast-metal grain.
	float roughness = clamp(base_roughness + finish.roughness_delta + (1.0 - detail) * 0.3, 0.2, 0.95);
	ROUGHNESS = weathered_roughness(roughness, armor_weathering);
}
