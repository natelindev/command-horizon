shader_type spatial;
uniform float wetness = 0.0;
varying vec3 world;
void vertex() { world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float a=dot(world.xz,vec2(.62,.24))+TIME*.8;
	float b=dot(world.xz,vec2(1.27,-.71))-TIME*1.1;
	float c=dot(world.xz,vec2(3.1,.8))+TIME*1.7;
	float wave=sin(a)*.55+sin(b)*.30+sin(c)*.15;
	ALBEDO=vec3(.055,.16,.18)+wave*.015;
	NORMAL_MAP=normalize(vec3(cos(a)*.12+cos(c)*.025,cos(b)*.08,1.0))*.5+.5;
	ROUGHNESS=.24+wetness*.10;
	METALLIC=.28;
}
