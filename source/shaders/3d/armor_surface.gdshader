shader_type spatial;

#include "res://source/shaders/3d/surface_detail.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.5);
uniform float metalness = 0.2;
uniform float base_roughness = 0.55;
varying vec3 armor_position;
varying vec3 armor_normal;

void vertex() {
	armor_position = VERTEX;
	armor_normal = NORMAL;
}

void fragment() {
	float detail = armor_panels ? armor_detail(armor_position, armor_normal) : 1.0;
	ALBEDO = base_color.rgb * detail;
	METALLIC = metalness;
	// Joint grime is slightly duller than the intact paint, with no invented bump map.
	ROUGHNESS = clamp(base_roughness + (1.0 - detail) * 0.3, 0.2, 0.95);
}
