shader_type spatial;
render_mode cull_disabled;

// Helix fabrication: the model prints upward in thin glowing layers behind a bright
// print line. The unbuilt volume is drawn by the hologram next pass.
#include "res://source/shaders/3d/construction_common.gdshaderinc"

const vec3 PRINT = vec3(0.32, 0.9, 1.0);
const vec3 FRESH = vec3(0.86, 0.95, 0.98);

void vertex()
{
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment()
{
  float height = world_position.y - floor_height;
  float assembled = assembled_height();
  if (height > assembled)
  {
    discard;
  }
  float settle = construction_settle();
  float below = assembled - height;
  float fresh = (1.0 - smoothstep(0.0, 0.55, below)) * settle;
  float layer = smoothstep(0.32, 0.48, abs(fract(height * 18.0) - 0.5));
  float line = 1.0 - smoothstep(0.0, 0.03, below);
  float halo = 1.0 - smoothstep(0.0, 0.16, below);
  ALBEDO = mix(original_albedo(UV), FRESH, fresh * 0.55);
  METALLIC = base_metallic;
  ROUGHNESS = mix(base_roughness, 0.2, fresh);
  float shimmer = steady ? 1.0 : 0.85 + 0.15 * sin(phase * 6.0 + height * 9.0);
  EMISSION =
      base_emission + PRINT * (line * 3.2 + halo * 0.9 + fresh * layer * 0.8) * shimmer * settle;
}
