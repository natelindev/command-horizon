shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, depth_test_disabled;

// Soft team-colored ground mark under mobile units.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0);
uniform float ground_height = 0.018;
uniform float strength = 0.65;

void vertex()
{
  VERTEX.y += ground_height;
}

void fragment()
{
  float distance_to_center = length(UV - vec2(0.5)) * 2.0;
  float rim = smoothstep(0.55, 0.82, distance_to_center) *
      (1.0 - smoothstep(0.85, 1.0, distance_to_center));
  float core = (1.0 - smoothstep(0.0, 0.88, distance_to_center)) * 0.36;

  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
  vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
  if (CLIP_SPACE_FAR < 0.0)
  {
    ndc.z = depth * 2.0 - 1.0;
  }
  vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  behind.xyz /= behind.w;
  bool is_occluded = VERTEX.z < behind.z - 0.15;

  ALBEDO = color.rgb;
  if (is_occluded)
  {
    ALPHA = (core * 0.4 + rim * 0.7) * strength * 0.45;
  }
  else
  {
    ALPHA = (core + rim * 1.2) * strength;
  }
}
