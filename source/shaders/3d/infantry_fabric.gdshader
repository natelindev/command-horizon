shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Matte, faded field cloth. Coordinates belong to each articulated mesh, so
// moving limbs retain their fabric instead of travelling through world noise.
uniform vec4 base_color : source_color = vec4(0.33, 0.35, 0.27, 1.0);
uniform float base_roughness : hint_range(0.0, 1.0) = 0.96;
uniform float object_detail : hint_range(0.0, 1.0) = 1.0;
uniform bool vertex_tint = true;
uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_surface_color = false;
uniform float fabric_scale : hint_range(0.5, 2.0) = 1.0;
uniform float fade_strength : hint_range(0.0, 0.3) = 0.20;
uniform float weave_strength : hint_range(0.0, 0.15) = 0.035;

varying vec3 fabric_position;
varying vec3 fabric_normal;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float cloth_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	vec3 w = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(cell), hash3(cell + vec3(1, 0, 0)), w.x),
			mix(hash3(cell + vec3(0, 1, 0)), hash3(cell + vec3(1, 1, 0)), w.x), w.y),
		mix(mix(hash3(cell + vec3(0, 0, 1)), hash3(cell + vec3(1, 0, 1)), w.x),
			mix(hash3(cell + vec3(0, 1, 1)), hash3(cell + vec3(1, 1, 1)), w.x), w.y), w.z);
}

float filtered_thread(float phase) {
	// Fade individual fibers before Nyquist. The low-frequency fading remains
	// at RTS distance without aliasing or an enlarged checkerboard pattern.
	float width = fwidth(phase);
	return sin(phase) * (1.0 - smoothstep(1.2, 3.14, width));
}

float weave(vec2 p, float irregularity) {
	vec2 phase = p * vec2(1120.0, 1430.0);
	float warp = filtered_thread(phase.x + irregularity * 4.1);
	float weft = filtered_thread(phase.y + irregularity * 2.3 + 0.65);
	// Unequal thread contributions avoid equal dark squares at intersections.
	return warp * 0.62 + weft * 0.38;
}

void vertex() {
	vec3 mesh_scale = max(vec3(length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz)), vec3(0.0001));
	fabric_position = VERTEX * mesh_scale * fabric_scale;
	fabric_normal = normalize(NORMAL / mesh_scale);
}

void fragment() {
	vec3 p = fabric_position;
	vec3 weights = pow(abs(normalize(fabric_normal)), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.0001);
	float broad = cloth_noise(p * vec3(18.0, 8.0, 18.0) + vec3(5.7, 2.1, 8.3));
	float grain = cloth_noise(p * vec3(63.0, 45.0, 63.0) + vec3(8.2, 6.5, 1.7));
	float fiber_filter = 1.0 - smoothstep(0.35, 0.9, length(fwidth(p * 155.0)));
	float fiber = (cloth_noise(p * 155.0 + vec3(4.1, 9.6, 3.3)) - 0.5) * fiber_filter;
	float threads = weave(p.zy, grain) * weights.x
		+ weave(p.xz, grain) * weights.y + weave(p.xy, grain) * weights.z;
	// Smooth tonal wear rather than camouflage: no thresholds or color islands.
	float fading = (broad - 0.5) * fade_strength
		+ (grain - 0.5) * fade_strength * 0.35;
	float scan = 0.0;
	if (use_surface_color) {
		vec3 texel = texture(surface_color, p.zy * 1.8).rgb * weights.x
			+ texture(surface_color, p.xz * 1.8).rgb * weights.y
			+ texture(surface_color, p.xy * 1.8).rgb * weights.z;
		vec3 mean = max(textureLod(surface_color, vec2(0.5), 12.0).rgb, vec3(0.02));
		scan = clamp(dot(texel / mean, vec3(0.2126, 0.7152, 0.0722)) - 1.0, -0.4, 0.4) * 0.07;
	}
	float detail = fading + threads * weave_strength + fiber * 0.14 + scan;
	ALBEDO = base_color.rgb * (1.0 + detail * object_detail);
	if (vertex_tint) {
		ALBEDO *= COLOR.rgb;
	}
	METALLIC = 0.0;
	SPECULAR = 0.14;
	ROUGHNESS = clamp(base_roughness + (grain - 0.5) * 0.045 * object_detail, 0.88, 1.0);
	// Screen-space surface gradient adds tiny fiber relief under standard Godot
	// lights. Derivatives filter with distance; the height itself remains local.
	float height = (threads * 0.000025 + (grain - 0.5) * 0.0008 + fiber * 0.00015) * object_detail;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, r1);
	vec3 gradient = (r1 * dFdx(height) + r2 * dFdy(height))
		* sign(determinant) / max(abs(determinant), 0.00000001);
	NORMAL = normalize(NORMAL - gradient);
}
