shader_type spatial;

uniform bool exterior = false;
uniform vec4 roads[3];
uniform vec2 checkpoints[3];
varying vec3 world_position;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float weather(vec2 p) {
	vec2 cell = floor(p);
	vec2 t = fract(p);
	t = t * t * (3.0 - 2.0 * t);
	return mix(mix(grain(cell), grain(cell + vec2(1, 0)), t.x),
		mix(grain(cell + vec2(0, 1)), grain(cell + vec2(1, 1)), t.x), t.y);
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float broad = weather(p * .065) * .65 + weather(p * .19) * .35;
	float wear = weather(p * .55);
	float grit = weather(p * 7.0);
	vec3 soil = mix(vec3(.34, .29, .205), vec3(.45, .385, .275), broad);
	soil += (wear - .5) * .055 + (grit - .5) * .018;
	float dry_channel = 1.0 - smoothstep(.06, .14,
		abs(sin(p.x * .048 + p.y * .021 + broad * 1.2)));
	soil *= 1.0 - dry_channel * .13;
	vec3 color = soil;
	if (!exterior) {
		float lane = 1000.0;
		float stripes = 0.0;
		for (int index = 0; index < 3; index++) {
			vec2 a = roads[index].xy;
			vec2 v = roads[index].zw - a;
			float along = clamp(dot(p - a, v) / dot(v, v), 0.0, 1.0);
			float d = length(p - a - v * along);
			lane = min(lane, d);
			float edge_line = 1.0 - smoothstep(.06, .13, abs(d - 4.15));
			edge_line *= step(1.2, mod(along * length(v), 4.5));
			stripes = max(stripes, edge_line);
		}
		float edge = lane + (wear - .5) * .55;
		float shoulder = 1.0 - smoothstep(4.5, 6.8, edge);
		float pavement = 1.0 - smoothstep(4.55, 5.15, edge);
		vec3 gravel = mix(vec3(.31, .30, .26), soil, .4) + (grit - .5) * .055;
		vec3 asphalt = mix(vec3(.17, .185, .17), vec3(.255, .25, .215), wear);
		float fissure = 1.0 - smoothstep(.012, .055,
			abs(sin(p.x * .53 + p.y * .81 + weather(p * .9) * .5)));
		asphalt *= 1.0 - fissure * .18 * smoothstep(.35, .65, broad);
		float tracks = 1.0 - smoothstep(.14, .32, abs(lane - 1.45));
		asphalt *= 1.0 - tracks * .10;
		asphalt = mix(asphalt, soil, smoothstep(.53, .76, wear) * .28);
		color = mix(color, gravel, shoulder * .88);
		color = mix(color, asphalt, pavement);
		color = mix(color, vec3(.59, .555, .43), stripes * pavement * smoothstep(.23, .62, wear) * .6);
		for (int index = 0; index < 3; index++) {
			vec2 q = p - checkpoints[index];
			float d = length(q);
			float apron = 1.0 - smoothstep(7.0, 7.8, d + (wear - .5) * .45);
			vec2 joints = abs(fract((q + 8.0) / 3.5) - .5);
			float seam = smoothstep(.483, .498, max(joints.x, joints.y));
			vec3 concrete = mix(vec3(.30, .30, .255), vec3(.41, .39, .31), wear);
			concrete *= 1.0 - seam * .15;
			concrete = mix(concrete, soil, smoothstep(.52, .77, broad) * .3);
			float ring = 1.0 - smoothstep(.06, .13, abs(d - 7.0));
			ring *= step(.30, fract((atan(q.y, q.x) + 3.14159) * 2.54648));
			concrete = mix(concrete, vec3(.69, .65, .50), ring * .72);
			float stop_line = 1.0 - smoothstep(.04, .10, abs(q.y + 4.7));
			stop_line *= step(abs(q.x), 4.5) * smoothstep(.25, .65, wear);
			concrete = mix(concrete, vec3(.64, .60, .46), stop_line * .65);
			color = mix(color, concrete, apron);
		}
	}
	ALBEDO = color;
	ROUGHNESS = .95;
}
