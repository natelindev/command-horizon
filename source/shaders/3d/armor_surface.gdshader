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
	float panel_mask = armor_panels ? armor_detail(armor_position, armor_normal) : 1.0;
	MetalFinish finish = metal_finish(armor_position, armor_normal, armor_to_view, VERTEX, NORMAL, UV2);
	vec3 shaded_normal = finish.normal;
	if (armor_panels && !trimmed) {
		shaded_normal = armor_relief_normal(armor_position, armor_normal, armor_to_view, shaded_normal, 1.0);
	}
	NORMAL = shaded_normal;
	float seam_ao = armor_panels ? mix(0.65, 1.0, smoothstep(0.55, 0.95, panel_mask)) : 1.0;
	AO = clamp(finish.occlusion * seam_ao, 0.22, 1.0);
	AO_LIGHT_AFFECT = 0.50;
	// Layer mechanical trim modules with secondary panel seam shading for rich detail everywhere.
	float detail = trimmed ? mix(finish.color, finish.color * panel_mask, armor_panels ? 0.38 : 0.0) : panel_mask * finish.color;
	ALBEDO = weathered(ground_dust(base_color.rgb * detail, armor_height), armor_weathering, true);
	// Chipped edges, fastener heads, and panel bevels expose bare steel.
	float edge_wear = 1.0 - armor_weathering.a;
	METALLIC = mix(metalness, 0.78, max(edge_wear * 0.65, finish.exposure * 0.55));
	SPECULAR = 0.56;
	RIM = 0.22;
	RIM_TINT = 0.34;
	// Roughness follows authored paint relief, recessed seams, and fine cast-metal grain.
	float seam_rough = clamp((1.0 - panel_mask) * 0.45, -0.08, 0.35);
	float roughness = clamp(base_roughness + finish.roughness_delta + seam_rough, 0.16, 0.96);
	ROUGHNESS = weathered_roughness(roughness, armor_weathering);
}
