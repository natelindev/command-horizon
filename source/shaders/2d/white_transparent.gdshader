shader_type canvas_item;

uniform sampler2D reference_texture : hint_default_white, repeat_disable;
// Matches the 3D fog: unexplored is opaque, explored memory stays partly readable.
uniform float explored_level = 0.25;
uniform float memory_opacity = 0.62;

void fragment()
{
  float visibility = textureLod(reference_texture, UV, 0.0).r;
  float memory = clamp(visibility / explored_level, 0.0, 1.0);
  float current = clamp((visibility - explored_level) / (1.0 - explored_level), 0.0, 1.0);
  COLOR.a *= mix(1.0, memory_opacity, memory) * (1.0 - current);
}
