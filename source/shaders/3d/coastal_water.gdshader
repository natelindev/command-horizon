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

float sea_height(vec2 p, float t, float detail_fade)
{
  vec2 c1 = p - vec2(t * 0.42, t * 0.16);
  vec2 c2 = p + vec2(t * 0.18, -t * 0.34);
  float h = (gnoise(c1 * 0.24) - 0.5) * 0.65;
  h += (gnoise(vec2(c1.x * 0.85 + c1.y * 0.52, -c1.x * 0.52 + c1.y * 0.85) * 0.85) - 0.5) * 0.45;
  h += (gnoise(vec2(c2.x * 0.72 - c2.y * 0.69, c2.x * 0.69 + c2.y * 0.72) * 1.75) - 0.5) * 0.30 * detail_fade;
  h += (gnoise(c1 * 3.6 + 7.1) - 0.5) * 0.16 * detail_fade;
  return h;
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
    float eps = 0.18;
    float h0 = sea_height(p, t, detail_fade);
    float hx = sea_height(p + vec2(eps, 0.0), t, detail_fade);
    float hy = sea_height(p + vec2(0.0, eps), t, detail_fade);
    slope = vec2(hx - h0, hy - h0) / eps * 0.095;

    float swell = gnoise(p * 0.18 - vec2(t * 0.2, t * 0.08));
    color += (swell - 0.5) * vec3(0.015, 0.035, 0.045);

    // Organic surf lap strictly near shorelines and breakwaters.
    float wash = sin(coast * 4.2 - t * 1.45 + gnoise(p * 0.55) * 3.5);
    float lacy = smoothstep(0.42, 0.72, gnoise(p * 2.1 - vec2(t * 0.25, t * 0.1)));
    foam = (1.0 - smoothstep(0.15, 1.35, coast)) * smoothstep(0.15, 0.85, wash) * lacy * 0.62;
  }

  vec3 view_normal = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
  NORMAL = view_normal;
  float ndotv = clamp(dot(view_normal, VIEW), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - ndotv, 5.0);
  color = mix(color, vec3(0.38, 0.54, 0.64), fresnel * (surface_effects ? 0.30 : 0.16));

  ALBEDO = mix(color, vec3(0.76, 0.84, 0.82), foam);
  ROUGHNESS = surface_effects ? mix(0.33 + shallows * 0.04, 0.48, foam) : 0.46;
  SPECULAR = surface_effects ? 0.18 : 0.14;
  METALLIC = 0.0;
}
