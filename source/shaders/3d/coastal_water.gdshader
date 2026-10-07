shader_type spatial;
varying vec3 world_position;
uniform vec4 shoreline[16];
uniform int shoreline_count = 11;
uniform float simulation_time = 0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=world_position.xz;
	float coast=1000.0;
	for(int i=0;i<16;i++) {
		if(i>=shoreline_count) { break; }
		vec2 a=shoreline[i].xy; vec2 axis=shoreline[i].zw-a;
		coast=min(coast,length(p-(a+axis*clamp(dot(p-a,axis)/dot(axis,axis),0.0,1.0))));
	}
	// The public sea continues past the map; only cosmetic water uses this extension.
	if(p.x<0.0 || p.x>128.0) {
		float outside=max(-p.x,p.x-128.0);
		float bank=15.0+smoothstep(2.0,14.0,outside)*(3.0*sin(p.x*.13)-2.5);
		coast=min(coast,abs(p.y-bank));
	}
	float t=simulation_time;
	float broad=noise(p*.19+vec2(t*.05,-t*.035));
	float warp=noise(p*.65+vec2(t*.06,0.0))*4.0;
	float ripple=sin(p.x*2.1+p.y*1.7+t*1.6+warp)*sin(p.x*.7-p.y*2.5-t*1.1+warp);
	float crest=smoothstep(.55,.91,ripple)*(0.2+0.8*broad);
	float shallows=1.0-smoothstep(.3,5.0,coast);
	float offshore=1.0-smoothstep(-8.0,10.0,p.y);
	vec3 color=mix(vec3(.032,.16,.225),vec3(.11,.32,.33),shallows);
	color=mix(color,vec3(.038,.135,.19),offshore*.46);
	color+=(broad-.5)*vec3(.025,.05,.07)+crest*vec3(.015,.025,.028);
	float wash=sin(coast*4.5-t*1.25+noise(p*.45)*2.0);
	float foam=(1.0-smoothstep(.18,1.5,coast))*smoothstep(.12,.85,wash);
	ALBEDO=mix(color,vec3(.64,.77,.72),foam*.72);
	NORMAL_MAP=vec3(.5+.018*sin(p.x*2.3+p.y*1.5+t+warp),.5+.016*cos(p.y*2.9-p.x+t*.8+warp),1.0);
	ROUGHNESS=.62+shallows*.12;
	SPECULAR=.28;
}
