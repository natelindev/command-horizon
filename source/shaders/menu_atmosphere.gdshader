shader_type canvas_item;
uniform float dimming = 0.05;
void fragment()
{
  float vignette = smoothstep(0.40, 1.05, length(UV - vec2(0.5)));
  float shade = clamp(dimming + vignette * 0.18, 0.0, 0.88);
  COLOR = vec4(vec3(0.01), shade);
}
