shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform vec4 deep : source_color = vec4(0.10, 0.20, 0.19, 1.0);
uniform vec4 shallow : source_color = vec4(0.32, 0.38, 0.30, 1.0);
uniform vec4 foam : source_color = vec4(0.82, 0.78, 0.68, 1.0);
uniform float clarity = 1.6;
uniform bool surface_effects = true;
uniform float simulation_time = 0.0;
uniform float flow_speed = 1.2;
uniform float wave_height = .065;
uniform bool has_flow_field = false;
uniform sampler2D flow_field : filter_linear, repeat_disable;
uniform vec2 flow_map_size = vec2(1.0);
uniform bool interactive_water = false;
uniform sampler2D ripple_state : filter_linear, repeat_disable;
uniform vec4 ripple_region = vec4(0.0, 0.0, 64.0, .5);
varying vec2 world_position;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

float hash(vec2 p)
{
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p)
{
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
      mix(hash(i), hash(i + vec2(1, 0)), f.x),
      mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
      f.y);
}
float ripple_height(vec2 uv)
{
  return texture(ripple_state, uv).r;
}
float ripple_fade(vec2 uv)
{
  vec2 edge = min(uv, vec2(1.0) - uv);
  return smoothstep(0.0, .08, min(edge.x, edge.y));
}
float flowing_noise(vec2 world, vec2 velocity, vec2 scale, float phase)
{
  // Two overlapping advection phases reset distortion without a visible jump.
  vec2 a = (world - velocity * phase * 6.0) * scale;
  vec2 b = (world - velocity * fract(phase + .5) * 6.0) * scale;
  return mix(noise(a), noise(b), abs(phase * 2.0 - 1.0));
}
void vertex()
{
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
  if (surface_effects)
  {
    float downstream = UV.x - simulation_time * flow_speed;
    if (interactive_water)
    {
      vec2 local_uv = (world_position - ripple_region.xy) / ripple_region.z;
      VERTEX.y += ripple_height(local_uv) * ripple_fade(local_uv);
    }
    VERTEX.y += wave_height * COLOR.r *
        (sin(downstream * 1.8 + UV.y * .6) * .65 + sin(downstream * 3.1 - UV.y * 1.2) * .35);
  }
}
void fragment()
{
  // Reconstruct depth for both reverse-Z rendering and OpenGL compatibility.
  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
  vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
  if (CLIP_SPACE_FAR < 0.0)
  {
    ndc.z = depth * 2.0 - 1.0;
  }
  vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  behind.xyz /= behind.w;
  float thickness = clamp((VERTEX.z - behind.z) / clarity, 0.0, 1.0);
  vec3 color = mix(shallow.rgb, deep.rgb, smoothstep(0.0, 1.0, thickness));
  ROUGHNESS = .36;
  SPECULAR = .22;
  if (surface_effects)
  {
    float t = simulation_time;
    // Everything is advected downstream in the same channel coordinates:
    // visible foam, ripples, eddies and colour carry with the current.
    vec2 p = vec2(UV.x - t * flow_speed, UV.y);
    float warp = noise(p * vec2(.32, .65));
    float a = p.x * 1.8 + p.y * .65 + warp * 4.0;
    float b = p.x * 2.5 - p.y * 1.7 + warp * 3.0;
    float wave = sin(a) * .65 + sin(b) * .35;
    vec4 field = texture(flow_field, world_position / flow_map_size);
    vec2 velocity = has_flow_field ? field.rg : normalize(UV2) * flow_speed;
    vec2 direction = length(velocity) > .01 ? normalize(velocity) : normalize(UV2);
    vec2 across = vec2(-direction.y, direction.x);
    vec2 slope =
        direction * (cos(a) * .07 + cos(b) * .035) + across * (cos(a) * .035 - cos(b) * .045);
    float local_foam = 0.0;
    if (interactive_water)
    {
      vec2 local_uv = (world_position - ripple_region.xy) / ripple_region.z;
      vec2 pixel = vec2(ripple_region.w / ripple_region.z, 0.0);
      float fade = ripple_fade(local_uv);
      slope += vec2(
                   ripple_height(local_uv + pixel.xy) - ripple_height(local_uv - pixel.xy),
                   ripple_height(local_uv + pixel.yx) - ripple_height(local_uv - pixel.yx)) /
          (2.0 * ripple_region.w) * fade;
      local_foam = texture(ripple_state, local_uv).b * fade;
    }
    NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
    float crest = smoothstep(.60, .94, wave);
    float shore = 1.0 - smoothstep(.01, .12, thickness);
    float wash = smoothstep(-.25, .65, sin(thickness * 24.0 - t * 1.8 + warp * 5.0));
    // Long, broken foam ribbons make the transport visible even when the
    // light is not catching a specular highlight (overcast and night).
    float phase = fract(t / 6.0);
    float ribbons = flowing_noise(world_position, velocity, vec2(.65, 1.8), phase);
    float streak = smoothstep(.55, .79, ribbons) * smoothstep(.25, .65, noise(p * .7));
    color += (warp - .5) * .085;
    color =
        mix(color,
            foam.rgb,
            clamp(shore * wash * .5 + streak * .33 + crest * .07 + local_foam * .8, 0.0, .85));
    ROUGHNESS = .48 + shore * .1;
  }
  ALBEDO = color;
  ALPHA = clamp(.55 + thickness * .8, 0.0, .97);
  METALLIC = .0;
}
