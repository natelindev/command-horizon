shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec4 color : source_color = vec4(vec3(0.0), 1.0);
uniform sampler2D world_visibility_texture : hint_default_white, filter_linear, repeat_disable;
uniform int texture_units_per_world_unit = 2;
uniform float outer_margin_for_fade_out = 2.0;
// Optional public scenery outside the playable rectangle; interior fog is unchanged.
uniform float exterior_visibility : hint_range(0.0, 1.0) = 0.0;
uniform float living_world_visibility = 0.0;
uniform bool debug_texture_view = false;
uniform sampler2D depth_texture : hint_depth_texture;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
// Explored ground outside current vision is remembered as a dim, cool, desaturated view
// rather than a flat dark veil. Unexplored ground keeps the opaque base color.
uniform vec3 memory_tint : source_color = vec3(0.78, 0.84, 0.92);
uniform float memory_brightness : hint_range(0.0, 1.0) = 0.55;
uniform float explored_level = 0.25;
uniform vec3 shroud_tint : source_color = vec3(0.025, 0.038, 0.055);

float shroud_hash(vec2 p)
{
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float shroud_noise(vec2 p)
{
  vec2 cell = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = shroud_hash(cell);
  float b = shroud_hash(cell + vec2(1.0, 0.0));
  float c = shroud_hash(cell + vec2(0.0, 1.0));
  float d = shroud_hash(cell + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex()
{
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment()
{
  ALBEDO = color.rgb;
  if (debug_texture_view && UV.x <= 0.2 && UV.y <= 0.2)
  {
    ALBEDO = textureLod(world_visibility_texture, vec2(UV * 5.0), 0.0).rgb;
    if (UV.x > 0.199 || UV.y > 0.199)
    {
      ALBEDO = vec3(1.0, 0.0, 0.0);
    }
  }

  ALPHA = 0.0;

  // depth is encoded on the first channel and is <0; 1>
  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).x;
  // transform depth from <0; 1> value to corresponding point in projection space <-1,-1,0; 1,1,1>*
  // * note that projection space in Vulkan is different than in OpenGL
  vec3 normalized_device_coordinates = vec3(SCREEN_UV * 2.0 - 1.0, depth);
  // move depth point from projection space to world space
  // * note that INV_PROJECTION_MATRIX is broken atm. so, let's use inverse(PROJECTION_MATRIX)
  vec4 world_position =
      INV_VIEW_MATRIX * inverse(PROJECTION_MATRIX) * vec4(normalized_device_coordinates, 1.0);
  world_position.xyz /= world_position.w;

  if (depth == 1.0) // infinite depth (OpenGL only)
  {
    ALPHA = 1.0;
  }
  else
  {
    vec2 world_visibility_texture_size_scaled =
        vec2(textureSize(world_visibility_texture, 0)) / float(texture_units_per_world_unit);
    vec2 world_visibility_texture_uv = world_position.xz / world_visibility_texture_size_scaled;
    if (world_visibility_texture_uv.x >= 0.0 && world_visibility_texture_uv.x <= 1.0 &&
        world_visibility_texture_uv.y >= 0.0 && world_visibility_texture_uv.y <= 1.0)
    {
      float visibility = textureLod(world_visibility_texture, world_visibility_texture_uv, 0.0).r;
      vec2 fog_uv = world_position.xz * 0.045;
      float wisp =
          shroud_noise(fog_uv) * 0.65 + shroud_noise(fog_uv * 2.15 + vec2(3.7, 1.9)) * 0.35;
      // Softly break up the circular shroud rim without altering full-vision edges.
      float rim_mask =
          smoothstep(0.0, 0.08, visibility) * (1.0 - smoothstep(explored_level, 0.65, visibility));
      float organic_vis = clamp(visibility + (wisp - 0.5) * 0.085 * rim_mask, 0.0, 1.0);
      float memory = clamp(organic_vis / explored_level, 0.0, 1.0);
      float current = clamp((organic_vis - explored_level) / (1.0 - explored_level), 0.0, 1.0);
      vec3 scene = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
      float luminance = dot(scene, vec3(0.2126, 0.7152, 0.0722));
      vec3 remembered = mix(vec3(luminance), scene, 0.45) * memory_brightness * memory_tint;
      vec3 shroud_color = mix(color.rgb, shroud_tint, 0.85) * (0.85 + 0.30 * wisp);
      ALBEDO = mix(shroud_color, remembered, memory);
      ALPHA = max(ALPHA, 1.0 - current);
    }
    else if (max(exterior_visibility, living_world_visibility) > 0.0)
    {
      float outside =
          max(max(-world_position.x, world_position.x - world_visibility_texture_size_scaled.x),
              max(-world_position.z, world_position.z - world_visibility_texture_size_scaled.y));
      float edge = textureLod(
                       world_visibility_texture,
                       clamp(world_visibility_texture_uv, vec2(0.0), vec2(1.0)),
                       0.0)
                       .r;
      float public_scenery =
          max(exterior_visibility, living_world_visibility) * smoothstep(0.0, 6.0, outside);
      float visibility = max(public_scenery, edge) *
          (1.0 -
           smoothstep(
               living_world_visibility > 0.0 ? 95.0 : 32.0,
               living_world_visibility > 0.0 ? 115.0 : 46.0,
               outside));
      ALPHA = 1.0 - visibility;
    }
    else if (
        outer_margin_for_fade_out > 0.0 &&
        ((world_position.x < 0.0 && world_position.x >= -outer_margin_for_fade_out) ||
         (world_position.x > world_visibility_texture_size_scaled.x &&
          world_position.x <= world_visibility_texture_size_scaled.x + outer_margin_for_fade_out) ||
         (world_position.z < 0.0 && world_position.z >= -outer_margin_for_fade_out) ||
         (world_position.z > world_visibility_texture_size_scaled.y &&
          world_position.z <= world_visibility_texture_size_scaled.y + outer_margin_for_fade_out)))
    {
      float max_distance_from_boundary = 0.0 - world_position.x;
      max_distance_from_boundary = max(
          max_distance_from_boundary, world_position.x - world_visibility_texture_size_scaled.x);
      max_distance_from_boundary = max(max_distance_from_boundary, 0.0 - world_position.z);
      max_distance_from_boundary = max(
          max_distance_from_boundary, world_position.z - world_visibility_texture_size_scaled.y);
      float alpha_from_margin =
          smoothstep(0.0, outer_margin_for_fade_out, max_distance_from_boundary) * 0.2 + 0.8;
      ALPHA = max(ALPHA, alpha_from_margin);

      float alpha_from_world_visibility_texture = 0.0;
      alpha_from_world_visibility_texture =
          1.0 - textureLod(world_visibility_texture, world_visibility_texture_uv, 0.0).r;
      ALPHA = max(ALPHA, alpha_from_world_visibility_texture);

      ALPHA = min(ALPHA, 1.0);
    }
    else
    {
      ALPHA = 1.0;
    }
  }

  if (debug_texture_view && UV.x <= 0.2 && UV.y <= 0.2)
  {
    ALPHA = 1.0;
  }
}
