shader_type spatial;
uniform float layout_scale = 1.0;
varying vec3 world_position;
uniform vec4 shoreline[16];
uniform int shoreline_count = 11;
uniform bool surface_effects = true;
uniform float simulation_time = 0.0;

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

vec2 sea_gradient(vec2 p, float t, float detail_fade)
{
  vec2 c1 = p - vec2(t * 0.42, t * 0.16);
  vec2 c2 = p + vec2(t * 0.18, -t * 0.34);
  vec2 g = gnoise_d(c1 * 0.24).yz * (0.24 * 0.65);
  mat2 r1 = mat2(vec2(0.85, -0.52), vec2(0.52, 0.85));
  g += (transpose(r1) * gnoise_d((r1 * c1) * 0.85).yz) * (0.85 * 0.45);
  if (detail_fade > 0.01)
  {
    mat2 r2 = mat2(vec2(0.72, 0.69), vec2(-0.69, 0.72));
    g += (transpose(r2) * gnoise_d((r2 * c2) * 1.75).yz) * (1.75 * 0.30 * detail_fade);
    g += gnoise_d(c1 * 3.6 + 7.1).yz * (3.6 * 0.16 * detail_fade);
  }
  return g;
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
  if (p.x < 0.0 || p.x > 128.0)
  {
    float outside = max(-p.x, p.x - 128.0);
    float bank = 15.0 + smoothstep(2.0, 14.0, outside) * (3.0 * sin(p.x * .13) - 2.5);
    coast = min(coast, abs(p.y - bank));
  }
  float t = surface_effects ? simulation_time : 0.0;
  float shallows = 1.0 - smoothstep(0.4, 5.5, coast);
  float offshore = 1.0 - smoothstep(-8.0, 14.0, p.y);

  vec3 deep_sea = vec3(0.032, 0.145, 0.21);
  vec3 coastal_teal = vec3(0.11, 0.33, 0.34);
  vec3 color = mix(deep_sea, coastal_teal, shallows);
  color = mix(color, vec3(0.025, 0.105, 0.165), offshore * 0.52);

  vec2 slope = vec2(0.0);
  float foam = 0.0;
  if (surface_effects)
  {
    float pixel_footprint = max(length(dFdx(p)), length(dFdy(p)));
    float detail_fade = 1.0 - smoothstep(0.08, 0.30, pixel_footprint);
    slope = sea_gradient(p, t, detail_fade) * 0.095;

    float swell = gnoise(p * 0.18 - vec2(t * 0.2, t * 0.08));
    color += (swell - 0.5) * vec3(0.015, 0.035, 0.045);

    float wash = sin(coast * 4.2 - t * 1.45 + gnoise(p * 0.55) * 3.5);
    float lacy = smoothstep(0.42, 0.72, gnoise(p * 2.1 - vec2(t * 0.25, t * 0.1)));
    foam = (1.0 - smoothstep(0.15, 1.35, coast)) * smoothstep(0.15, 0.85, wash) * lacy * 0.62;
  }

  vec3 view_normal =
      normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
  NORMAL = view_normal;
  float ndotv = clamp(dot(view_normal, VIEW), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - ndotv, 5.0);
  color = mix(color, vec3(0.38, 0.54, 0.64), fresnel * (surface_effects ? 0.30 : 0.16));

  ALBEDO = mix(color, vec3(0.76, 0.84, 0.82), foam);
  ROUGHNESS = surface_effects ? mix(0.07 + shallows * 0.03, 0.52, foam) : 0.36;
  SPECULAR = surface_effects ? 0.55 : 0.24;
  METALLIC = 0.0;
}
