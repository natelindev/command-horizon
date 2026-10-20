shader_type spatial;
#include "res://source/shaders/3d/terrain_layers.gdshaderinc"
// Ground for authored, elevated battlefields. A per-map control texture marks
// roads (R), water beds and fords (G), forest floor (B) and sand (A); slope
// exposes rock, bare slickrock shows through in patches, and higher tiers read
// slightly lighter so elevation is legible from above.

uniform sampler2D control : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(192.0, 160.0);
uniform float tier_step = 3.0;
uniform vec4 ground_low : source_color = vec4(0.47, 0.29, 0.21, 1.0);
uniform vec4 ground_high : source_color = vec4(0.73, 0.55, 0.38, 1.0);
uniform vec4 accent : source_color = vec4(0.52, 0.48, 0.30, 1.0);
uniform vec4 road : source_color = vec4(0.58, 0.42, 0.28, 1.0);
uniform vec4 rock : source_color = vec4(0.55, 0.33, 0.24, 1.0);
uniform vec4 bed : source_color = vec4(0.30, 0.27, 0.22, 1.0);
uniform vec4 forest_floor : source_color = vec4(0.30, 0.30, 0.18, 1.0);
uniform vec4 slickrock : source_color = vec4(0.84, 0.62, 0.45, 1.0);
uniform vec4 sand : source_color = vec4(0.86, 0.68, 0.50, 1.0);
uniform float accent_amount = 0.35;
uniform float slickrock_amount = 0.0;
uniform vec4 crust : source_color = vec4(0.94, 0.93, 0.89, 1.0);
uniform float crust_amount = 0.0;
// Farmland: sand-mask areas become ploughed fields of alternating crops.
uniform float furrow_amount = 0.0;
uniform vec4 snow : source_color = vec4(0.93, 0.95, 0.97, 1.0);
// Snow cover on low ground and from the 6 m tier up; 0 leaves the ground bare.
uniform float snow_amount = 0.0;
uniform float snow_high = 0.0;
uniform vec4 crop : source_color = vec4(0.62, 0.55, 0.30, 1.0);
uniform vec4 crop_alt : source_color = vec4(0.40, 0.48, 0.22, 1.0);
uniform float strata = 1.0;

varying vec3 world_point;
varying vec3 world_normal;

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

// Distance to the nearest Voronoi cell border: polygonal salt-crust plates.
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
  world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment()
{
  vec2 p = world_point.xz;
  vec4 mask = texture(control, p / map_size);
  // Wide, soft taps let shores and forest edges bleed naturally.
  vec2 texel = 1.0 / vec2(textureSize(control, 0));
  vec4 soft = (texture(control, p / map_size + vec2(texel.x * 3.0, 0.0))
               + texture(control, p / map_size - vec2(texel.x * 3.0, 0.0))
               + texture(control, p / map_size + vec2(0.0, texel.y * 3.0))
               + texture(control, p / map_size - vec2(0.0, texel.y * 3.0)))
              * 0.25;
  // Beyond the battlefield the landscape carries no roads, water or forest.
  vec2 uv = p / map_size;
  float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
  mask *= inside;
  soft *= inside;
  float macro = noise(p * .06) * .6 + noise(p * .19) * .4;
  float grain = noise(p * 3.1);
  vec3 color = mix(ground_low.rgb, ground_high.rgb, macro);
  color = mix(color, accent.rgb, smoothstep(.55, .8, noise(p * .11 + 7.3)) * accent_amount);
  // Higher tiers read lighter; a darker band hugs each tier's foot.
  float level = world_point.y / max(tier_step, .1);
  color *= .93 + clamp(level, -1.0, 2.0) * .045;
  // Bare, cross-bedded slickrock exposures on open ground.
  float slick = smoothstep(.64, .74, noise(p * .055 + 11.7) * .7 + noise(p * .17) * .3)
                * slickrock_amount;
  float bedding = smoothstep(.9, 1.0, sin((p.x * .7 + p.y * .35 + noise(p * .2) * 4.0) * 2.2) * .5 + .5);
  color = mix(color, slickrock.rgb * (.92 + macro * .12) * (1.0 - bedding * .1), slick);
  // Salt flats: bright crust plates with raised, darker pressure ridges.
  if (crust_amount > 0.0)
  {
    float plates = plate_edge(p * .45);
    float ridge = 1.0 - smoothstep(.03, .12, plates);
    // Crust forms only on the pan floor; raised terraces stay gravel.
    float crusted = crust_amount * smoothstep(.3, .6, noise(p * .04 + 3.7) * .8 + .25)
                    * (1.0 - smoothstep(1.2, 2.4, world_point.y));
    color = mix(color, crust.rgb * (.96 + grain * .05), crusted);
    color = mix(color, color * .8, ridge * crusted * .6);
  }
  // Snow drifts over open ground and deepens with altitude; wind scours
  // patches bare. Roads, gravel and ice (the sand mask) are painted over it.
  float snowed = 0.0;
  if (max(snow_amount, snow_high) > 0.0)
  {
    float cover = mix(snow_amount, snow_high, smoothstep(-.5, 6.0, world_point.y));
    float drift = noise(p * .045 + 5.3) * .65 + noise(p * .21 + 1.7) * .35;
    snowed = smoothstep(.88 - cover, 1.12 - cover, drift);
    float ripple = sin(dot(p, vec2(.8, .35)) * 2.6 + noise(p * .3) * 4.0) * .5 + .5;
    color = mix(color, snow.rgb * (.95 + ripple * .04 + grain * .03), snowed);
  }
  float sandy = max(mask.a, soft.a * .7);
  float ripples = sin(p.x * 2.1 + p.y * .6 + noise(p * .4) * 3.0) * .5 + .5;
  vec3 sand_color = sand.rgb * (.94 + ripples * .05 + grain * .05);
  if (furrow_amount > 0.0)
  {
    // Fields alternate crops in large blocks; furrows run in rows within each.
    float block = step(.5, hash(floor(p / 26.0)));
    vec2 axis = block > .5 ? vec2(1.0, .15) : vec2(.15, 1.0);
    float furrow = smoothstep(.35, .65, sin(dot(p, axis) * 3.6) * .5 + .5);
    vec3 field = mix(crop.rgb, crop_alt.rgb, step(.5, hash(floor(p / 26.0) + 3.1)));
    sand_color = mix(sand_color, field * (.82 + furrow * .22 + grain * .05), furrow_amount);
  }
  color = mix(color, sand_color, sandy * .9);
  // A light, broken litter layer under trees rather than a painted patch.
  float forest = max(mask.b, soft.b * .6) * smoothstep(.3, .7, noise(p * .35 + 4.2));
  color = mix(color, forest_floor.rgb * (.85 + macro * .3), forest * .3);
  float lane = mask.r;
  color = mix(color, road.rgb * (.9 + macro * .18), lane * .85);
  color *= 1.0 - (1.0 - smoothstep(.0, .12, abs(lane - .55))) * .06;
  float wet = clamp(soft.g * 1.6, 0.0, 1.0);
  color = mix(color, bed.rgb, wet * .55);
  color = mix(color, bed.rgb * .8, mask.g * .9);
  // Cliffs: banded rock with strata following elevation.
  float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
  float cliff = smoothstep(.28, .55, slope + (grain - .5) * .12);
  float band = noise(vec2(world_point.y * 1.7, p.x * .05 + p.y * .05)) * strata;
  vec3 stone = rock.rgb * (.78 + band * .35 + grain * .08);
  // Scanned ground detail on walkable surfaces: roads take the path layer,
  // slickrock, sand, salt crust and snow the biome accent. Steep faces keep the
  // procedural rock, which top-down projection would smear.
  float feature = clamp(max(max(slick, sandy * .8), max(crust_amount * .7, snowed * .9)), 0.0, 1.0);
  TerrainSurface ground = terrain_surface(p, color + (grain - .5) * .03, lane, feature, .95);
  ALBEDO = mix(ground.albedo, stone, cliff);
  ROUGHNESS = mix(ground.roughness, .82, cliff);
  AO = mix(ground.occlusion, 1.0, cliff);
  ground.slope *= 1.0 - cliff;
  NORMAL = terrain_normal(ground, NORMAL, VIEW_MATRIX, INV_VIEW_MATRIX);
}
