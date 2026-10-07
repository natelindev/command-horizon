shader_type spatial;
uniform vec4 base_tint : source_color = vec4(0.3,0.34,0.32,1.0);
uniform float metallic = 0.0;
varying vec3 world_point;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
	vec3 c=floor(p);vec3 t=fract(p);t=t*t*(3.0-2.0*t);
	return mix(mix(mix(hash(c),hash(c+vec3(1,0,0)),t.x),mix(hash(c+vec3(0,1,0)),hash(c+vec3(1,1,0)),t.x),t.y),
		mix(mix(hash(c+vec3(0,0,1)),hash(c+vec3(1,0,1)),t.x),mix(hash(c+vec3(0,1,1)),hash(c+vec3(1)),t.x),t.y),t.z);
}
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float stain=noise(world_point*vec3(.75,.32,.75));
	float streak=smoothstep(.48,.78,noise(world_point*vec3(2.4,.16,2.4)));
	float fine=noise(world_point*9.0);
	ALBEDO=base_tint.rgb*(.79+stain*.28+fine*.08-streak*.14);
	ROUGHNESS=.88;
	METALLIC=metallic;
}
