shader_type spatial;
render_mode cull_disabled;

// Bastion assembly: a dark steel skeleton climbs ahead of a level, white-hot weld
// line; freshly welded courses carry red-oxide primer before the final paint.
#include "res://source/shaders/3d/construction_common.gdshaderinc"

const vec3 SKELETON = vec3(0.16, 0.18, 0.2);
const vec3 PRIMER = vec3(0.3, 0.1, 0.06);
const float SKELETON_REACH = 1.1;

float girder_distance(float coordinate, float spacing)
{
  return abs(fract(coordinate / spacing + 0.5) - 0.5) * spacing;
}

void vertex()
{
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment()
{
  float height = world_position.y - floor_height;
  float assembled = assembled_height();
  float settle = construction_settle();
  if (height > assembled)
  {
    // Columns follow the face's own tangent axes; floor beams ring every half metre.
    vec3 facing = abs(world_normal);
    float column_x = girder_distance(world_position.x, 1.2);
    float column_z = girder_distance(world_position.z, 1.2);
    float column = facing.x > 0.7 ? column_z : (facing.z > 0.7 ? column_x : 10.0);
    if (facing.y > 0.7)
    {
      column = min(column_x, column_z);
    }
    float beam = facing.y > 0.7 ? 10.0 : girder_distance(height, 0.55);
    float reach = 1.0 - smoothstep(0.0, SKELETON_REACH, height - assembled);
    if (min(column, beam) > 0.035 * reach || reach <= 0.0)
    {
      discard;
    }
    ALBEDO = SKELETON;
    METALLIC = 0.65;
    ROUGHNESS = 0.45;
  }
  else
  {
    float below = assembled - height;
    vec3 color = original_albedo(UV);
    float primer = (1.0 - smoothstep(0.06, 0.4, below)) * settle;
    ALBEDO = mix(color, PRIMER, primer * 0.65);
    METALLIC = mix(base_metallic, 0.2, primer);
    ROUGHNESS = mix(base_roughness, 0.75, primer);
    float seam = 1.0 - smoothstep(0.0, 0.085, below);
    float core = 1.0 - smoothstep(0.0, 0.025, below);
    float arc = flicker(vec3(floor(world_position.xz * 3.0), 1.0), 14.0);
    vec3 weld = mix(vec3(1.0, 0.42, 0.1), vec3(1.0, 0.86, 0.62), core);
    EMISSION = base_emission + weld * seam * arc * 2.6 * settle;
  }
}
