shader_type spatial;
uniform bool hot = false;
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
  float ripple =
      sin(p.x * .81 + p.y * .37 + TIME * .6) * .6 + sin(p.x * .24 - p.y * .67 - TIME * .4) * .4;
  float molten = smoothstep(.42, .62, noise(p * .4 + noise(p * .13)));
  ALBEDO = hot ? mix(vec3(.10, .07, .06), vec3(.5, .12, .02), molten)
               : vec3(.07, .22, .24) + ripple * .008;
  ROUGHNESS = hot ? .8 : .48;
  METALLIC = hot ? .0 : .08;
  EMISSION = hot ? vec3(.3, .045, .002) * molten : vec3(0.0);
  NORMAL_MAP = vec3(.5 + ripple * .012, .5 + cos(p.x * .3 + p.y * .6 + TIME) * .012, 1.0);
}
