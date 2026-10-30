shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;

// One transparent pass. No ray marching, extra viewport, lights or world-sized
// particle volumes. Reconstruct only the visible ground for drifting weather.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float simulation_time = 0.0;
uniform float clouds = 0.0;
uniform float dust = 0.0;
uniform float mist = 0.0;
uniform float daylight = 1.0;
uniform float ground_height = 0.0;
uniform bool high_quality = false;
uniform vec3 haze_color : source_color = vec3(.7, .78, .8);
uniform vec3 dust_color : source_color = vec3(.65, .48, .29);

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
float banks(vec2 p)
{
  float n = noise(p) * .72 + noise(p * 2.13 + 19.7) * .28;
  if (high_quality)
  {
    n = n * .86 + noise(p * 4.37) * .14;
  }
  return smoothstep(.30, .76, n);
}
void vertex()
{
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
void fragment()
{
  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
  vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
  if (CLIP_SPACE_FAR < 0.0)
  {
    ndc.z = depth * 2.0 - 1.0;
  }
  vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
  view.xyz /= view.w;
  vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
  vec2 wind = vec2(simulation_time * .65, simulation_time * .24);
  float alpha = 0.0;
  vec3 premultiplied = vec3(0.0);
  if (clouds > .001)
  {
    float shadow = banks((world.xz - wind) * .038) * clouds * .10;
    alpha = shadow;
    // Orthographic rays are parallel. Intersect a cloud deck above the
    // terrain, so cloud wisps drift separately from their ground shadows.
    vec3 ray = normalize(INV_VIEW_MATRIX[2].xyz);
    float rise = max(0.0, ground_height + 20.0 - world.y);
    vec2 deck = world.xz + ray.xz * rise / max(.2, abs(ray.y));
    float cloud = banks((deck - wind) * .038) * clouds * .08;
    premultiplied = haze_color * mix(.4, 1.12, daylight) * cloud;
    alpha = cloud + alpha * (1.0 - cloud);
  }
  if (mist > .001 || dust > .001)
  {
    float low = exp(-max(0.0, world.y - ground_height) * .11);
    float wisps = banks((world.xz - wind * .65) * vec2(.065, .14));
    float fog = mist * low * (.05 + wisps * .12);
    float grit = dust * low * wisps * .14;
    vec3 tint = mix(haze_color, dust_color, grit / max(.001, fog + grit));
    float veil = clamp(fog + grit, 0.0, .16);
    premultiplied = premultiplied * (1.0 - veil) + tint * mix(.35, 1.0, daylight) * veil;
    alpha = veil + alpha * (1.0 - veil);
  }
  ALBEDO = premultiplied / max(.001, alpha);
  ALPHA = alpha;
}
