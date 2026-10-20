shader_type spatial;
render_mode cull_disabled;
// Lava for authored battlefields: dark cooled crust plates drift slowly over
// molten rock that glows through the seams and wells up in open pools, with a
// slow pulse of heat. Opaque; its light comes from emission.

uniform vec4 crust : source_color = vec4(0.09, 0.07, 0.06, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.32, 0.05, 1.0);
uniform vec4 core : source_color = vec4(1.0, 0.5, 0.1, 1.0);
uniform float heat = 1.5;
uniform bool surface_effects = true;
uniform float simulation_time = 0.0;
uniform vec2 flow = vec2(0.05, 0.03);

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

// Distance to the nearest Voronoi cell border: the cooled crust plates.
float plate_edge(vec2 p)
{
  vec2 cell = floor(p);
  vec2 local = fract(p);
  float nearest = 8.0;
  float second = 8.0;
  for (int y = -1; y <= 1; y++)
  {
    for (int x = -1; x <= 1; x++)
    {
      vec2 offset = vec2(float(x), float(y));
      vec2 seed = offset + vec2(hash(cell + offset), hash(cell + offset + 17.3)) - local;
      float span = dot(seed, seed);
      if (span < nearest)
      {
        second = nearest;
        nearest = span;
      }
      else if (span < second)
      {
        second = span;
      }
    }
  }
  return sqrt(second) - sqrt(nearest);
}

void vertex()
{
  world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment()
{
  if (!surface_effects)
  {
    ALBEDO = crust.rgb;
    EMISSION = glow.rgb * (.3 + noise(world_point.xz * .3) * .35);
    ROUGHNESS = .9;
  }
  else
  {
    float t = simulation_time;
    vec2 p = world_point.xz + flow * t * 2.4;
    p += vec2(noise(p * .19 + t * .045), noise(p * .17 - t * .035)) * 1.8;
    p += vec2(noise(p * .9), noise(p * .9 + 23.7)) * .5;
    float seam = 1.0 - smoothstep(0.0, 0.21, plate_edge(p * 0.35));
    float molten = smoothstep(0.60, 0.86, noise(p * 0.12 + t * 0.02));
    float pulse = 0.92 + 0.08 * sin(t * .7 + noise(world_point.xz * 0.5) * 6.283);
    float hot = clamp(max(seam, molten), 0.0, 1.0);
    vec3 lava = mix(glow.rgb, core.rgb, clamp(molten * 0.7 + seam * 0.3, 0.0, 1.0));
    vec3 rock = crust.rgb * (0.8 + noise(p * 2.1) * 0.4);
    ALBEDO = mix(rock, lava * 0.4, hot);
    EMISSION = lava * hot * heat * pulse;
    ROUGHNESS = mix(0.92, 0.32, hot);
  }
}
