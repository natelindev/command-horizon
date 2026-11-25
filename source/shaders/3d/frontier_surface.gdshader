shader_type spatial;
render_mode cull_disabled;

#include "res://source/shaders/3d/surface_detail.gdshaderinc"
#include "res://source/shaders/3d/metal_detail.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.3, 0.32, 0.22, 1.0);
uniform float metalness = 0.0;
uniform bool fabric = false;
varying vec3 local_position;
varying vec3 local_normal;
varying vec4 local_weathering;
varying float world_height;
varying mat3 metal_to_view;
varying vec3 metal_position;

float hash(vec3 p)
{
  return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float noise(vec3 p)
{
  vec3 i = floor(p);
  vec3 f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
  return mix(
      mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
          mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x),
          f.y),
      mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
          mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x),
          f.y),
      f.z);
}
void vertex()
{
  vec3 scale = max(vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz),
    length(MODEL_MATRIX[2].xyz)), vec3(0.0001));
  metal_position = VERTEX * scale;
  metal_to_view = mat3(MODELVIEW_MATRIX[0].xyz / scale.x,
    MODELVIEW_MATRIX[1].xyz / scale.y, MODELVIEW_MATRIX[2].xyz / scale.z);
  local_position = VERTEX;
  local_normal = NORMAL;
  local_weathering = COLOR;
  world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment()
{
  vec3 p = local_position;
  float wear = noise(p * 5.0);
  float dust = noise(p * 1.7 + vec3(8.0));
  vec3 color = base_color.rgb * (0.76 + wear * 0.28);
  float roughness;
  float metal_out = metalness;
  color = mix(color, vec3(0.30, 0.255, 0.17), smoothstep(0.45, 0.85, dust) * 0.26);
  if (fabric)
  {
    float folds = sin(p.z * 8.0 + noise(p * 2.0) * 2.0);
    float seams = 1.0 - smoothstep(0.025, 0.07, abs(fract(p.z * 0.8) - 0.5));
    color *= 0.88 + folds * 0.03 - seams * 0.12;
    roughness = 0.94;
  }
  else
  {
    float chips = smoothstep(0.74, 0.88, noise(p * 42.0));
    color = mix(color, vec3(0.14, 0.125, 0.10), chips * 0.28);
    roughness = mix(0.62, 0.89, dust);
  }
  bool trimmed = trim_enabled && UV2.x > 0.0001 && UV2.y > 0.0001;
  float panel_mask = armor_panels ? armor_detail(local_position, local_normal) : 1.0;
  float panels = panel_mask;
  // A uniform material branch avoids metal sampling on cloth and concrete.
  if (armor_panels && !fabric) {
    MetalFinish finish = metal_finish(metal_position, local_normal, metal_to_view, VERTEX, NORMAL, UV2);
    vec3 n = finish.normal;
    if (!trimmed) {
      n = armor_relief_normal(local_position, local_normal, metal_to_view, n, 1.0);
    }
    NORMAL = n;
    float seam_ao = mix(0.68, 1.0, smoothstep(0.55, 0.95, panel_mask));
    AO = clamp(finish.occlusion * seam_ao, 0.22, 1.0);
    AO_LIGHT_AFFECT = 0.50;
    roughness += finish.roughness_delta + clamp((1.0 - panel_mask) * 0.35, -0.05, 0.30);
    panels = trimmed ? mix(finish.color, finish.color * panel_mask, 0.38) : panel_mask * finish.color;
    metal_out = mix(metalness, 0.72, max((1.0 - local_weathering.a) * 0.55, finish.exposure * 0.50));
  }
  color *= panels;
  ALBEDO = weathered(ground_dust(color, world_height), local_weathering, !fabric);
  ROUGHNESS = weathered_roughness(roughness, local_weathering);
  METALLIC = metal_out;
  SPECULAR = fabric ? 0.25 : 0.54;
  RIM = fabric ? 0.10 : 0.20;
  RIM_TINT = 0.32;
}
