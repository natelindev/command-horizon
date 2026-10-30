shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

// Soft team-colored ground mark under mobile units.
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
  ALBEDO = color.rgb;
  ALPHA = (core + rim * 1.2) * strength;
}
