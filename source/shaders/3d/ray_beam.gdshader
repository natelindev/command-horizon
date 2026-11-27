shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;

uniform vec4 beam_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float intensity : hint_range(0.0, 10.0) = 2.5;
uniform float scroll_speed = 6.0;
uniform bool is_prism = false;
// 0: fired beam, 1: allied transfer, 2: refraction, 3: thermal needle.
uniform int beam_role = 0;

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
  float across = (UV.y - 0.5) * 2.0;
  float d = abs(across);
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
  vec3 split_light = vec3(0.0);
  if (is_prism)
  {
    // Optical dispersion separates into two fine ribbons, focused at both ends.
    // Keep a stable axis: light refracts instead of writhing like electricity.
    float focus = sin(UV.x * 3.141593);
    float separation = focus * (0.25 + smoothstep(0.0, 0.7, progress) * 0.22);
    float blue = exp(-pow((across - separation) / 0.10, 2.0));
    float violet = exp(-pow((across + separation) / 0.10, 2.0));
    split_light = (vec3(0.2, 0.85, 1.0) * blue + vec3(0.78, 0.35, 1.0) * violet) *
        (1.0 - smoothstep(0.05, 1.0, progress));
    core = exp(-d * d * 120.0);
    sheath *= 0.3;
  }
  float ion = 0.8 + 0.2 * turbulence;
  float hot = core * core_life;
  float halo = sheath * sheath_life * ion;
  vec3 energy =
      core_color.rgb * hot * (is_prism ? 0.85 : 1.8) + tint * halo * 0.75 + split_light * 0.85;
  float opacity = hot + halo * 0.65 + length(split_light) * 0.55;
  if (beam_role == 1)
  {
    // A calm, narrow feeder carries a single packet toward the firing crystal.
    float envelope =
        (0.2 + 0.8 * smoothstep(0.0, 0.16, progress)) * (1.0 - smoothstep(0.55, 1.0, progress));
    float packet = exp(-pow((UV.x - mix(-0.12, 1.12, progress)) / 0.16, 2.0));
    float thread = exp(-d * d * 42.0);
    opacity = thread * envelope * (0.5 + packet * 0.5);
    energy = (tint * 0.9 + core_color.rgb * packet * 0.45) * thread;
  }
  else if (beam_role == 2)
  {
    // Refracted branches collapse quickly into a fine violet filament.
    float life = 1.0 - smoothstep(0.0, 1.0, progress);
    float filament = exp(-d * d * mix(35.0, 120.0, progress));
    opacity = filament * life;
    energy = (core_color.rgb * 0.7 + tint * 0.4) * opacity;
  }
  else if (beam_role == 3)
  {
    // Thermal optics leave a straight amber heat trace, without prism splitting.
    float life = 1.0 - smoothstep(0.02, 1.0, progress);
    opacity = (core * core_life + sheath * life * 0.25);
    energy = core_color.rgb * core * core_life + tint * sheath * life * 0.45;
  }
  // Soft HDR shoulder keeps single beams crisp while preventing stacked volleys
  // from blowing out into an opaque white block under additive bloom.
  vec3 raw_energy = energy * intensity;
  vec3 toned_energy = raw_energy / (vec3(1.0) + raw_energy * 0.22);
  ALBEDO = toned_energy;
  EMISSION = toned_energy * 0.85;
  ALPHA = clamp(opacity * edge * ends * beam_color.a, 0.0, 0.96);
}
