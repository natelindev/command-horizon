shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.5, 0.57, 0.6, 1.0);
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform bool has_texture = false;
uniform float base_metallic = 0.0;
uniform float base_roughness = 0.8;
uniform float floor_height = 0.0;
uniform float total_height = 4.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
varying vec3 world_position;

void vertex()
{
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment()
{
  float height = world_position.y - floor_height;
  float assembled = total_height * mix(0.025, 1.0, progress);
  vec3 original = base_color.rgb;
  if (has_texture)
  {
    original *= texture(base_texture, UV).rgb;
  }
  if (height > assembled)
  {
    // Sparse blueprint lines leave the unfinished volume visibly open.
    vec3 cell = abs(fract(world_position * 2.0) - 0.5);
    float grid = max(cell.x, max(cell.y, cell.z));
    if (grid < 0.475)
    {
      discard;
    }
    ALBEDO = vec3(0.17, 0.29, 0.32);
    EMISSION = vec3(0.15, 0.33, 0.37) * (0.3 + 0.15 * sin(phase * 2.0));
    ROUGHNESS = 0.9;
  }
  else
  {
    ALBEDO = original;
    METALLIC = base_metallic;
    ROUGHNESS = base_roughness;
    float seam = 1.0 - smoothstep(0.015, 0.1, abs(height - assembled));
    float sweep = 0.65 + 0.35 * sin(world_position.x * 5.0 + phase * 5.0);
    EMISSION = vec3(0.9, 0.65, 0.26) * seam * sweep;
  }
}
