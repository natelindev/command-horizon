shader_type spatial;
uniform vec4 base_tint : source_color = vec4(0.25,0.3,0.32,1.0);
uniform bool snow = false;
varying vec3 world_point;
float hash(vec3 p) {
	return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);
}
float noise(vec3 p) {
	vec3 cell=floor(p);vec3 t=fract(p);t=t*t*(3.0-2.0*t);
	return mix(mix(mix(hash(cell),hash(cell+vec3(1,0,0)),t.x),
		mix(hash(cell+vec3(0,1,0)),hash(cell+vec3(1,1,0)),t.x),t.y),
		mix(mix(hash(cell+vec3(0,0,1)),hash(cell+vec3(1,0,1)),t.x),
		mix(hash(cell+vec3(0,1,1)),hash(cell+vec3(1,1,1)),t.x),t.y),t.z);
}
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float stain=noise(world_point*0.7);
	float fine=noise(world_point*6.0);
	float exposure=snow ? 0.91+stain*0.08+fine*0.06 : 0.77+stain*0.30+fine*0.14;
	ALBEDO=base_tint.rgb*exposure;
	ROUGHNESS=0.96;
}
