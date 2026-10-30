shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform vec4 color : source_color = vec4(1.0);
uniform float width_pixels = 15.0;
uniform float edge_width_pixels = 1.0;
// Non-zero half extents draw a rectangular ring of that size instead.
uniform vec2 half_extents = vec2(0.0);

varying vec3 vertex_model;

void vertex()
{
  vertex_model = VERTEX;
}

void fragment()
{
  ALBEDO.rgb = color.rgb;
  float alpha = 0.0;
  if (half_extents.x > 0.0)
  {
    vec2 q = abs(vertex_model.xz) - half_extents;
    float signed_distance = max(q.x, q.y);
    vec2 gradient = vec2(dFdx(signed_distance), dFdy(signed_distance));
    float rangeFromLine = signed_distance / length(gradient);
    alpha = smoothstep(-width_pixels, -width_pixels + edge_width_pixels, rangeFromLine);
    alpha = min(alpha, 1.0 - smoothstep(-edge_width_pixels, 0.0, rangeFromLine));
  }
  else if (UV.x == 0.5 && UV.y == 0.5)
  {
    alpha = 0.0;
  }
  else
  {
    vec2 center_uv = vec2(0.5);
    float uv_dist_to_center_uv = distance(UV, center_uv);
    float edge_dist_to_center_uv = 0.5;
    float vertex_dist_to_center_model = length(vertex_model);
    // proportions:
    //   uv_dist_to_center_uv - vertex_dist_to_center_model
    // edge_dist_to_center_uv - edge_dist_to_center_model
    float edge_dist_to_center_model =
        edge_dist_to_center_uv * vertex_dist_to_center_model / uv_dist_to_center_uv;
    float signed_distance = vertex_dist_to_center_model - edge_dist_to_center_model;
    vec2 gradient = vec2(dFdx(signed_distance), dFdy(signed_distance));
    float rangeFromLine = signed_distance / length(gradient);
    alpha = smoothstep(-width_pixels, -width_pixels + edge_width_pixels, rangeFromLine);
    alpha = min(alpha, 1.0 - smoothstep(-edge_width_pixels, 0.0, rangeFromLine));
  }

  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
  vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
  if (CLIP_SPACE_FAR < 0.0)
  {
    ndc.z = depth * 2.0 - 1.0;
  }
  vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  behind.xyz /= behind.w;
  bool is_occluded = VERTEX.z < behind.z - 0.15;

  if (is_occluded)
  {
    ALPHA = alpha * 0.5;
    EMISSION = color.rgb * 0.45;
  }
  else
  {
    ALPHA = alpha;
  }
}

