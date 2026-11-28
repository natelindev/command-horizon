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

vec3 gnoise_d(vec2 p)
{
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
  vec2 ga = grad(i);
  vec2 gb = grad(i + vec2(1.0, 0.0));
  vec2 gc = grad(i + vec2(0.0, 1.0));
  vec2 gd = grad(i + vec2(1.0, 1.0));
  float va = dot(ga, f);
  float vb = dot(gb, f - vec2(1.0, 0.0));
  float vc = dot(gc, f - vec2(0.0, 1.0));
  float vd = dot(gd, f - vec2(1.0, 1.0));
  float k1 = vb - va;
  float k2 = vc - va;
  float k3 = va - vb - vc + vd;
  float val = (va + k1 * u.x + k2 * u.y + k3 * u.x * u.y) * 0.5 + 0.5;
  vec2 dval = 0.5 * (ga + (gb - ga) * u.x + (gc - ga) * u.y + (ga - gb - gc + gd) * u.x * u.y +
                     du * vec2(k1 + k3 * u.y, k2 + k3 * u.x));
  return vec3(val, dval);
}

vec2 river_gradient(vec2 p, float t)
{
  vec2 flow = p - vec2(t * 0.85, 0.0);
  vec2 g = gnoise_d(flow * 0.35).yz * (0.35 * 0.55);
  mat2 r = mat2(vec2(0.85, -0.5), vec2(0.5, 0.85));
  g += (transpose(r) * gnoise_d((r * flow) * 1.1).yz) * (1.1 * 0.40);
  g += gnoise_d(flow * 2.8 + vec2(0.0, t * 0.2)).yz * (2.8 * 0.22);
  return g;
}

void vertex()
{
  world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment()
{
  vec2 p = world.xz;
  float t = surface_effects ? simulation_time : 0.0;
  vec2 slope = surface_effects ? river_gradient(p, t) * 0.095 : vec2(0.0);
  vec3 view_normal =
      normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
  NORMAL = view_normal;
  float ndotv = clamp(dot(view_normal, VIEW), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - ndotv, 5.0);
  vec3 base = vec3(0.052, 0.165, 0.185);
  ALBEDO = mix(base, vec3(0.32, 0.48, 0.54), fresnel * (surface_effects ? 0.30 : 0.16));
  ROUGHNESS = surface_effects ? (0.08 + wetness * 0.05) : 0.36;
  SPECULAR = surface_effects ? 0.55 : 0.24;
  METALLIC = 0.0;
}
