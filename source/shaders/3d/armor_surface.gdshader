shader_type spatial;

#include "res://source/shaders/3d/surface_detail.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.5);
uniform float metalness = 0.2;
uniform float base_roughness = 0.55;
varying vec3 armor_position;
varying vec3 armor_normal;
varying vec4 armor_weathering;
varying float armor_height;

void vertex() {
	armor_position = VERTEX;
	armor_normal = NORMAL;
	armor_weathering = COLOR;
	armor_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float detail = armor_panels ? armor_detail(armor_position, armor_normal) : 1.0;
	ALBEDO = weathered(ground_dust(base_color.rgb * detail, armor_height), armor_weathering, true);
	// Chipped edges expose bare steel.
	METALLIC = mix(metalness, 0.7, (1.0 - armor_weathering.a) * 0.5);
	// Joint grime is slightly duller than the intact paint, with no invented bump map.
	float roughness = clamp(base_roughness + (1.0 - detail) * 0.3, 0.2, 0.95);
	ROUGHNESS = weathered_roughness(roughness, armor_weathering);
}
