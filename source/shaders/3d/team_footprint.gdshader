shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, world_vertex_coords;

// Soft team-colored ground mark under mobile units. Vertices are flattened onto the
// (flat) battlefield so aircraft also mark their ground position.
uniform vec4 color : source_color = vec4(1.0);
uniform float ground_height = 0.018;
uniform float strength = 0.34;

void vertex()
{
  VERTEX.y = ground_height;
}

void fragment()
{
  float distance_to_center = length(UV - vec2(0.5)) * 2.0;
  float rim = smoothstep(0.58, 0.86, distance_to_center) *
      (1.0 - smoothstep(0.86, 1.0, distance_to_center));
  float core = (1.0 - smoothstep(0.0, 0.9, distance_to_center)) * 0.3;
  ALBEDO = color.rgb;
  ALPHA = (core + rim) * strength;
}
