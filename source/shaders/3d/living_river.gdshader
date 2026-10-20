shader_type spatial;
uniform bool surface_effects = true;
uniform float simulation_time = 0.0;
uniform float wetness = 0.0;
varying vec3 world;
void vertex()
{
  world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment()
{
  vec2 current = world.xz - vec2(simulation_time * .8, 0.0);
  float a = dot(current, vec2(.62, .24));
  float b = dot(current, vec2(1.27, -.71));
  float c = dot(current, vec2(3.1, .8));
  float wave = surface_effects ? sin(a) * .55 + sin(b) * .30 + sin(c) * .15 : 0.0;
  ALBEDO = vec3(.055, .16, .18) + wave * .035 + smoothstep(.65, .95, wave) * .12;
  vec2 slope = surface_effects ? vec2(cos(a) * .18 + cos(c) * .045, cos(b) * .13) : vec2(0.0);
  NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
  ROUGHNESS = .24 + wetness * .10;
  METALLIC = .28;
}
