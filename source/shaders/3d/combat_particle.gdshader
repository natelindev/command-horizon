shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float glow = 0.0;
uniform float rough_edge = 0.45;

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 v = fract(sin(vec4(dot(i, vec2(127.1, 311.7)), dot(i + vec2(1,0), vec2(127.1,311.7)), dot(i + vec2(0,1), vec2(127.1,311.7)), dot(i + vec2(1,1), vec2(127.1,311.7)))) * 43758.5453);
	return mix(mix(v.x,v.y,f.x),mix(v.z,v.w,f.x),f.y);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float cloud = noise(UV * 9.0) * 0.65 + noise(UV * 21.0) * 0.35;
	float edge = length(p) + (cloud - 0.5) * rough_edge;
	float density = 1.0 - smoothstep(0.25, 0.98, edge);
	ALBEDO = COLOR.rgb * mix(0.7, 1.15, cloud);
	EMISSION = COLOR.rgb * glow * density;
	ALPHA = COLOR.a * density;
}
