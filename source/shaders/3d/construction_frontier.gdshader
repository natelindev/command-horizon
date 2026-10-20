shader_type spatial;
render_mode cull_disabled;

// Frontier salvage: the model is patched together plate by plate. Fresh plates
// show mismatched scrap, dark bolted seams and grinder-hot edges along a ragged front.
#include "res://source/shaders/3d/construction_common.gdshaderinc"

const float PLATE = 0.42;
const vec3 RUST = vec3(0.3, 0.13, 0.06);
const vec3 OLIVE = vec3(0.22, 0.23, 0.13);
const vec3 STEEL = vec3(0.34, 0.35, 0.34);
const vec3 FADED = vec3(0.2, 0.26, 0.3);

float plate_edge(vec3 coordinate, vec3 facing)
{
  vec3 local = abs(fract(coordinate / PLATE) - 0.5);
  // Ignore the axis that runs through the face.
  if (facing.x > 0.7)
  {
    local.x = 0.0;
  }
  else if (facing.y > 0.7)
  {
    local.y = 0.0;
  }
  else if (facing.z > 0.7)
  {
    local.z = 0.0;
  }
  return max(local.x, max(local.y, local.z));
}

void vertex()
{
  construction_local_position = VERTEX;
  construction_local_normal = NORMAL;
  construction_weathering = COLOR;
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment()
{
  float height = world_position.y - floor_height;
  float settle = construction_settle();
  vec3 cell = floor(world_position / PLATE);
  float chance = construction_hash(cell);
  float pick = construction_hash(cell + vec3(17.3, 5.1, 9.7));
  float plate_front = assembled_height() + (chance - 0.5) * 0.55 * settle;
  if (height > plate_front)
  {
    discard;
  }
  float below = plate_front - height;
  float fresh = (1.0 - smoothstep(0.25, 1.4, below)) * settle;
  vec3 scrap = pick < 0.3 ? RUST : (pick < 0.55 ? OLIVE : (pick < 0.8 ? STEEL : FADED));
  scrap *= 0.82 + 0.3 * construction_hash(floor(world_position * 9.0));
  float seam = smoothstep(0.43, 0.48, plate_edge(world_position, abs(world_normal)));
  vec3 color = mix(original_albedo(UV), scrap, fresh * 0.75);
  ALBEDO = color * (1.0 - seam * fresh * 0.55);
  METALLIC = mix(base_metallic, 0.45, fresh);
  ROUGHNESS = mix(base_roughness, 0.82, fresh);
  float hot = (1.0 - smoothstep(0.0, 0.07, below)) * step(0.45, pick);
  vec3 glow = mix(vec3(1.0, 0.36, 0.06), vec3(1.0, 0.72, 0.32), chance);
  EMISSION = base_emission + glow * hot * flicker(cell, 10.0) * 2.4 * settle;
}
