shader_type spatial;
uniform float layout_scale = 1.0;
varying vec3 world_position;
uniform vec4 shoreline[16];
uniform int shoreline_count = 11;
uniform bool surface_effects = true;
uniform float simulation_time = 0.0;
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
      mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x),
      f.y);
}
void vertex()
{
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment()
{
  vec2 p = world_position.xz / layout_scale;
  float coast = 1000.0;
  for (int i = 0; i < 16; i++)
  {
    if (i >= shoreline_count)
    {
      break;
    }
    vec2 a = shoreline[i].xy;
    vec2 axis = shoreline[i].zw - a;
    coast =
        min(coast, length(p - (a + axis * clamp(dot(p - a, axis) / dot(axis, axis), 0.0, 1.0))));
  }
  // The public sea continues past the map; only cosmetic water uses this extension.
  if (p.x < 0.0 || p.x > 128.0)
  {
    float outside = max(-p.x, p.x - 128.0);
    float bank = 15.0 + smoothstep(2.0, 14.0, outside) * (3.0 * sin(p.x * .13) - 2.5);
    coast = min(coast, abs(p.y - bank));
  }
  float t = surface_effects ? simulation_time : 0.0;
  vec2 current = p - vec2(t * .45, t * .18);
  float broad = noise(current * .19);
  float warp = noise(current * .65) * 4.0;
  float ripple =
      sin(current.x * 2.1 + current.y * 1.7 + warp) * sin(current.x * .7 - current.y * 2.5 + warp);
  float crest = smoothstep(.55, .91, ripple) * (0.2 + 0.8 * broad);
  float shallows = 1.0 - smoothstep(.3, 5.0, coast);
  float offshore = 1.0 - smoothstep(-8.0, 10.0, p.y);
  vec3 color = mix(vec3(.032, .16, .225), vec3(.11, .32, .33), shallows);
  color = mix(color, vec3(.038, .135, .19), offshore * .46);
  color += (broad - .5) * vec3(.025, .05, .07) + crest * vec3(.07, .09, .10);
  float wash = sin(coast * 4.5 - t * 1.25 + noise(p * .45) * 2.0);
  float foam = (1.0 - smoothstep(.18, 1.5, coast)) * smoothstep(.12, .85, wash);
  float streak = surface_effects ? smoothstep(.62, .81, noise(current * vec2(.3, 2.4))) * .32 : 0.0;
  ALBEDO = mix(color, vec3(.64, .77, .72), foam * .72 + streak);
  vec2 slope =
      vec2(.15 * sin(p.x * 2.3 + p.y * 1.5 + t + warp), .12 * cos(p.y * 2.9 - p.x + t * .8 + warp));
  NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
  if (!surface_effects)
  {
    NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
  }
  ROUGHNESS = .23 + shallows * .18;
  SPECULAR = .28;
}
