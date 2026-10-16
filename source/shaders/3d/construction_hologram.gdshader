shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

// Helix hologram of the unbuilt volume: a translucent cyan silhouette with bright
// rims and scan bands rising through it. Shared by every surface of one site.
uniform float floor_height = 0.0;
uniform float total_height = 4.0;
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform bool steady = false;
varying vec3 world_position;

void vertex()
{
  world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment()
{
  float height = world_position.y - floor_height;
  float assembled = total_height * mix(0.025, 1.0, progress);
  if (height <= assembled)
  {
    discard;
  }
  float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
  float scan = smoothstep(0.36, 0.5, abs(fract(height * 3.2 - phase * 0.45) - 0.5));
  float grain = smoothstep(0.25, 0.5, abs(fract(height * 22.0) - 0.5));
  float pulse = steady ? 1.0 : 0.9 + 0.1 * sin(phase * 3.1);
  float settle = 1.0 - smoothstep(0.92, 1.0, progress);
  ALBEDO = mix(vec3(0.2, 0.72, 0.95), vec3(0.75, 0.98, 1.0), rim) * 1.35;
  ALPHA = clamp(0.1 + grain * 0.06 + rim * 0.6 + scan * 0.26, 0.0, 0.85) * pulse * settle;
}
