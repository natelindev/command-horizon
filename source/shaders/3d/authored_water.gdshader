shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Water for authored battlefields: colour deepens with real depth below the
// surface, the bed shows through in the shallows, a soft foam line marks the
// shore and slow ripples break up reflections. Biome palettes set the tints.

uniform vec4 deep : source_color = vec4(0.10, 0.20, 0.19, 1.0);
uniform vec4 shallow : source_color = vec4(0.32, 0.38, 0.30, 1.0);
uniform vec4 foam : source_color = vec4(0.82, 0.78, 0.68, 1.0);
uniform float clarity = 1.6;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

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
  float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
  vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
  behind.xyz /= behind.w;
  float thickness = clamp((VERTEX.z - behind.z) / clarity, 0.0, 1.0);
  float ripple = noise(p * .6 + vec2(TIME * .15, TIME * .08)) * .6
                 + noise(p * 1.7 - vec2(TIME * .1, -TIME * .12)) * .4;
  vec3 color = mix(shallow.rgb, deep.rgb, smoothstep(0.0, 1.0, thickness));
  float shore = 1.0 - smoothstep(0.02, 0.18, thickness);
  float lace = smoothstep(.45, .7, noise(p * 2.3 + TIME * .2));
  color = mix(color, foam.rgb, shore * (.35 + lace * .4));
  ALBEDO = color + (ripple - .5) * .02;
  ALPHA = clamp(.45 + thickness * .9, 0.0, .96);
  ROUGHNESS = .12;
  METALLIC = .05;
  SPECULAR = .6;
  NORMAL_MAP = vec3(.5 + (ripple - .5) * .08, .5 + (noise(p * .9 - TIME * .1) - .5) * .08, 1.0);
}
