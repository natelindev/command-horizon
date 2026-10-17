shader_type spatial;
uniform vec4 low : source_color;
uniform vec4 high : source_color;
uniform vec4 road : source_color;
uniform int surface = 0;
uniform int road_count = 0;
uniform vec4 roads[16];
varying vec3 world_point;
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
void vertex()
{
  world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment()
{
  vec2 p = world_point.xz;
  float macro = noise(p * .075) * .65 + noise(p * .23) * .35;
  float grain = noise(p * 3.8);
  vec3 color = mix(low.rgb, high.rgb, macro);
  if (surface == 1)
  {
    float crust = smoothstep(.46, .51, noise(p * .7));
    color = mix(color * .85, high.rgb, crust * .65);
  }
  else if (surface == 2)
  {
    color = mix(color, high.rgb, smoothstep(.48, .7, macro) * .7);
  }
  else if (surface == 3)
  {
    vec2 joints = abs(fract(p / 4.0) - .5);
    color *= 1.0 - smoothstep(.475, .5, max(joints.x, joints.y)) * .13;
  }
  else if (surface == 4)
  {
    color *= .8 + grain * .25;
  }
  float distance_to_road = 1000.0;
  for (int i = 0; i < 16; i++)
  {
    if (i >= road_count)
    {
      break;
    }
    vec2 a = roads[i].xy;
    vec2 b = roads[i].zw;
    vec2 d = b - a;
    distance_to_road =
        min(distance_to_road,
            length(p - a - d * clamp(dot(p - a, d) / max(dot(d, d), .001), 0.0, 1.0)));
  }
  float lane = 1.0 - smoothstep(2.4, 3.7, distance_to_road + (grain - .5) * .45);
  color = mix(color, road.rgb * (.92 + macro * .16), lane * .72);
  float tracks = 1.0 - smoothstep(.08, .2, abs(distance_to_road - 1.1));
  color *= 1.0 - tracks * .08;
  ALBEDO = color + (grain - .5) * .025;
  ROUGHNESS = .94;
}
