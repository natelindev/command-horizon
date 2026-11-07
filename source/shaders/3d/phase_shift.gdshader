shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float progress = 0.0;
uniform bool arriving = false;
uniform bool ground_ring = false;
uniform bool silhouette = false;
varying vec3 local;

void vertex() {
	local = VERTEX;
	if (!ground_ring && !silhouette) {
		float size = arriving ? mix(0.2, 1.3, progress) : pow(1.0 - progress, 1.5);
		VERTEX *= max(0.01, size);
	}
}

void fragment() {
	float fade = pow(1.0 - progress, 1.3);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float bands = pow(0.5 + 0.5 * sin(local.y * 26.0 - progress * 18.0), 10.0);
	float alpha = (rim * 0.85 + bands * 0.4) * fade;
	vec3 color = mix(vec3(0.01, 0.025, 0.05), vec3(0.2, 0.85, 1.0), rim + bands * 0.25);
	if (silhouette) {
		color = mix(vec3(0.005, 0.015, 0.025), vec3(0.12, 0.55, 0.7), rim * 0.5);
		alpha = (0.65 + rim * 0.3) * fade;
	}
	if (ground_ring) {
		float radius = arriving ? mix(0.03, 0.48, progress) : mix(0.4, 0.01, progress);
		float ring = exp(-pow((length(UV - vec2(0.5)) - radius) * 85.0, 2.0));
		alpha = ring * fade * 0.65;
		color = vec3(0.2, 0.85, 1.0);
	}
	ALBEDO = color;
	EMISSION = color * (ground_ring ? 0.6 : rim);
	ALPHA = alpha;
}
