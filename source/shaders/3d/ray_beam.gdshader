shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 beam_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 10.0) = 2.5;
uniform float scroll_speed = 6.0;
uniform bool is_prism = false;

float noise(vec2 p)
{
  vec2 cell = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  vec4 n = fract(
      sin(vec4(
          dot(cell, vec2(127.1, 311.7)),
          dot(cell + vec2(1.0, 0.0), vec2(127.1, 311.7)),
          dot(cell + vec2(0.0, 1.0), vec2(127.1, 311.7)),
          dot(cell + vec2(1.0, 1.0), vec2(127.1, 311.7)))) *
      43758.5453);
  return mix(mix(n.x, n.y, f.x), mix(n.z, n.w, f.x), f.y);
}

void fragment()
{
  float d = abs(UV.y - 0.5) * 2.0;
  float core = exp(-d * d * 24.0);
  float sheath = exp(-d * d * 3.5);
  // Driven entirely by age: pausing also freezes the optical turbulence.
  vec2 flow = vec2(UV.x * 32.0 - progress * scroll_speed, UV.y * 7.0);
  float turbulence = noise(flow) * 0.65 + noise(flow * 2.3) * 0.35;
  float core_life = pow(1.0 - smoothstep(0.06, 0.35, progress), 2.0);
  float expansion = 1.0 + progress * 0.55;
  float disturbed = max(0.0, d / expansion + (turbulence - 0.5) * progress * 0.36);
  sheath = mix(sheath, exp(-disturbed * disturbed * 3.5), smoothstep(0.0, 0.25, progress));
  float dissolve = smoothstep(progress * 1.15 - 0.15, progress * 1.15 + 0.2, turbulence);
  float sheath_life = (1.0 - smoothstep(0.08, 1.0, progress)) * dissolve;
  // Zero at ribbon edges/endpoints: no rectangular silhouette, even without bloom.
  float edge = 1.0 - smoothstep(0.68, 1.0, d);
  float ends = smoothstep(0.0, 0.025, UV.x) * (1.0 - smoothstep(0.975, 1.0, UV.x));
  vec3 tint = beam_color.rgb;
  if (is_prism)
  {
    // Dispersion lives mostly outside the white core, with restrained axial bands.
    float wavelength = UV.y * 0.8 + UV.x * 1.6 - progress * 0.35;
    vec3 spectrum = 0.5 + 0.5 * cos(6.283185 * (wavelength + vec3(0.0, 0.33, 0.67)));
    tint = mix(tint, spectrum, 0.62 + d * 0.2);
  }
  float ion = 0.8 + 0.2 * turbulence;
  float hot = core * core_life;
  float halo = sheath * sheath_life * ion;
  vec3 energy = core_color.rgb * hot * 1.8 + tint * halo * 0.75;
  // Carry the white-hot core in the unshaded color output as well as emission.
  ALBEDO = energy * intensity;
  EMISSION = energy * intensity;
  ALPHA = clamp((hot + halo * 0.65) * edge * ends * beam_color.a, 0.0, 1.0);
}
