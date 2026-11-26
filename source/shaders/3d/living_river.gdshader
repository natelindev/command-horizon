shader_type spatial;
uniform bool surface_effects = true;
uniform float simulation_time = 0.0;
uniform float wetness = 0.0;
varying vec3 world;

float hash(vec2 p)
{
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 grad(vec2 i)
{
  float angle = hash(i) * 6.2831853;
  return vec2(cos(angle), sin(angle));
}

float gnoise(vec2 p)
{
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(grad(i), f);
  float b = dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
  float c = dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
  float d = dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

float river_height(vec2 p, float t)
{
  vec2 flow = p - vec2(t * 0.85, 0.0);
  float h = (gnoise(flow * 0.35) - 0.5) * 0.55;
  h += (gnoise(vec2(flow.x * 0.85 + flow.y * 0.5, -flow.x * 0.5 + flow.y * 0.85) * 1.1) - 0.5) * 0.40;
  h += (gnoise(flow * 2.8 + vec2(0.0, t * 0.2)) - 0.5) * 0.22;
  return h;
}

void vertex()
{
  world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment()
{
  vec2 p = world.xz;
  float t = surface_effects ? simulation_time : 0.0;
  vec2 slope = vec2(0.0);
  if (surface_effects)
  {
    float eps = 0.16;
    float h0 = river_height(p, t);
    float hx = river_height(p + vec2(eps, 0.0), t);
    float hy = river_height(p + vec2(0.0, eps), t);
    slope = vec2(hx - h0, hy - h0) / eps * 0.095;
  }
  vec3 view_normal = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
  NORMAL = view_normal;
  float ndotv = clamp(dot(view_normal, VIEW), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - ndotv, 5.0);
  vec3 base = vec3(0.052, 0.165, 0.185);
  ALBEDO = mix(base, vec3(0.32, 0.48, 0.54), fresnel * (surface_effects ? 0.30 : 0.16));
  ROUGHNESS = surface_effects ? (0.32 + wetness * 0.06) : 0.46;
  SPECULAR = surface_effects ? 0.18 : 0.14;
  METALLIC = 0.0;
}
