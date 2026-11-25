shader_type canvas_item;

uniform float dimming = 0.05;
uniform float left_focus : hint_range(0.0, 1.0) = 0.0;
uniform vec3 accent_tint : source_color = vec3(0.91, 0.69, 0.29);

void fragment() {
	float vignette = smoothstep(0.38, 1.08, length((UV - vec2(0.56, 0.48)) * vec2(1.0, 1.15)));
	// Soft directional scrim along the left third so menu typography floats cleanly over artwork.
	float left_scrim = (1.0 - smoothstep(0.08, 0.56, UV.x)) * left_focus * 0.48;
	float bottom_scrim = smoothstep(0.68, 1.0, UV.y) * left_focus * 0.18;
	float shade = clamp(dimming + vignette * 0.22 + left_scrim + bottom_scrim, 0.0, 0.90);
	vec3 tint = mix(vec3(0.015, 0.022, 0.028), accent_tint * 0.06 + vec3(0.015, 0.02, 0.025), 0.35);
	COLOR = vec4(tint, shade);
}
