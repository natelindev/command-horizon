shader_type spatial;
render_mode cull_disabled;
// Layered sandstone for cliffs, ramp cuts and formations: horizontal strata
// keyed to world height, desert-varnish streaks down the faces, a pale
// weathered caprock on level tops and grain at close range.

uniform vec4 band_dark : source_color = vec4(0.48, 0.22, 0.13, 1.0);
uniform vec4 band_mid : source_color = vec4(0.66, 0.34, 0.19, 1.0);
uniform vec4 band_light : source_color = vec4(0.80, 0.55, 0.36, 1.0);
uniform vec4 cap : source_color = vec4(0.78, 0.60, 0.42, 1.0);
uniform vec4 varnish : source_color = vec4(0.20, 0.12, 0.09, 1.0);
uniform float strata_scale = 1.6;
uniform float rock_roughness = 0.92;

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

void vertex()
{
  world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
  world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment()
{
  vec2 along = vec2(world_point.x + world_point.z, world_point.y);
  float wobble = noise(along * vec2(0.08, 0.0) + 3.1) * 0.9;
  float layer = (world_point.y + wobble) * strata_scale;
  float band = fract(layer);
  float which = hash(vec2(floor(layer), 7.0));
  vec3 color = mix(band_dark.rgb, band_mid.rgb, smoothstep(0.15, 0.35, which));
  color = mix(color, band_light.rgb, smoothstep(0.7, 0.9, which));
  // Thin darker partings between beds.
  color *= 1.0 - (1.0 - smoothstep(0.0, 0.08, band)) * 0.18;
  float grain = noise(along * vec2(2.3, 5.1));
  color *= 0.9 + grain * 0.18;
  // Varnish runs down from the rim in vertical streaks.
  float streak = noise(vec2((world_point.x + world_point.z) * 0.9, 0.0));
  float runoff = smoothstep(0.55, 0.85, streak) * smoothstep(-1.0, 3.0, world_point.y);
  color = mix(color, varnish.rgb, runoff * 0.35);
  // Level tops weather to a paler caprock.
  float level_top = smoothstep(0.75, 0.95, world_normal.y);
  color = mix(color, cap.rgb * (0.88 + grain * 0.2), level_top);
  ALBEDO = color;
  ROUGHNESS = rock_roughness;
}
