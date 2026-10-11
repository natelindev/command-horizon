shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color = vec4(0.3, 0.32, 0.22, 1.0);
uniform float metalness = 0.0;
uniform bool fabric = false;
varying vec3 local_position;

float hash(vec3 p)
{
  return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}
float noise(vec3 p)
{
  vec3 i = floor(p);
  vec3 f = smoothstep(vec3(0.0), vec3(1.0), fract(p));
  return mix(
      mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
          mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x),
          f.y),
      mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
          mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x),
          f.y),
      f.z);
}
void vertex()
{
  local_position = VERTEX;
}
void fragment()
{
  vec3 p = local_position;
  float wear = noise(p * 5.0);
  float dust = noise(p * 1.7 + vec3(8.0));
  vec3 color = base_color.rgb * (0.78 + wear * 0.25);
  color = mix(color, vec3(0.30, 0.255, 0.17), smoothstep(0.48, 0.85, dust) * 0.24);
  if (fabric)
  {
    float folds = sin(p.z * 8.0 + noise(p * 2.0) * 2.0);
    float seams = 1.0 - smoothstep(0.025, 0.07, abs(fract(p.z * 0.8) - 0.5));
    color *= 0.90 + folds * 0.018 - seams * 0.08;
    ROUGHNESS = 0.96;
  }
  else
  {
    float chips = smoothstep(0.76, 0.88, noise(p * 42.0));
    color = mix(color, vec3(0.12, 0.105, 0.08), chips * 0.25);
    ROUGHNESS = mix(0.68, 0.91, dust);
  }
  ALBEDO = color;
  METALLIC = metalness;
}
