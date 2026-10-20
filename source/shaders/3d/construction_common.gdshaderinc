// Shared inputs for the faction construction shaders. Each building site gets one
// material per surface; the original surface is approximated from these values.
#include "res://source/shaders/3d/surface_detail.gdshaderinc"
uniform vec4 base_color : source_color = vec4(0.5, 0.57, 0.6, 1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform bool has_texture = false;
uniform vec3 base_emission = vec3(0.0);
uniform float base_metallic = 0.0;
uniform float base_roughness = 0.8;
uniform float floor_height = 0.0;
uniform float total_height = 4.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
// Reduced flashes: hold glowing accents steady instead of flickering.
uniform bool steady = false;
varying vec3 world_position;
varying vec3 world_normal;
varying vec3 construction_local_position;
varying vec3 construction_local_normal;
// Each faction's vertex() copies COLOR here so sites keep the baked weathering.
varying vec4 construction_weathering;

float construction_hash(vec3 p)
{
  return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float assembled_height()
{
  return total_height * mix(0.025, 1.0, progress);
}

// Fresh-work accents fade out over the last few percent, so the swap back to the
// finished materials at completion does not pop.
float construction_settle()
{
  return 1.0 - smoothstep(0.92, 1.0, progress);
}

vec3 original_albedo(vec2 uv)
{
  vec3 color = base_color.rgb;
  if (has_texture)
  {
    color *= texture(base_texture, uv).rgb;
  }
  if (armor_panels)
  {
    color *= armor_detail(construction_local_position, construction_local_normal);
  }
  return weathered(color, construction_weathering, armor_panels);
}

float flicker(vec3 cell, float rate)
{
  if (steady)
  {
    return 0.8;
  }
  return 0.55 + 0.45 * construction_hash(cell + floor(phase * rate));
}
