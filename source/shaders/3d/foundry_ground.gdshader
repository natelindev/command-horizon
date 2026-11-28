shader_type spatial;
#include "res://source/shaders/3d/terrain_layers.gdshaderinc"
varying vec3 world_position;
uniform vec4 roads[8];
uniform float wetness = 0.0;

uniform int road_count = 6;
uniform float road_half_width = 4.0;
uniform vec2 pavement_center = vec2(90.0,58.0);
uniform vec2 pavement_extent = vec2(64.0,44.0);
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=world_position.xz;
	// Sub-pixel grain fades to its mean instead of shimmering at battle zoom.
	float fine=mix(.5,hash(floor(p*24.0)),1.0-smoothstep(.5,1.5,length(fwidth(p))*24.0));
	float wear=noise(p*.28);
	vec3 earth=mix(vec3(.20,.22,.175),vec3(.255,.247,.198),noise(p*.08));
	vec2 district=abs(p-pavement_center)-pavement_extent;
	float paved=1.0-smoothstep(-1.0,3.0,max(district.x,district.y));
	// Rail loading yard, south utilities court and east maintenance access.
	vec2 north=abs(p-vec2(72.0,-22.0))-vec2(43.0,13.0);
	vec2 south=abs(p-vec2(88.0,134.0))-vec2(38.0,11.0);
	vec2 east=abs(p-vec2(180.0,58.0))-vec2(13.0,10.0);
	float yards=min(min(max(north.x,north.y),max(south.x,south.y)),max(east.x,east.y));
	paved=max(paved,1.0-smoothstep(-1.0,2.5,yards));
	vec2 tiles=abs(fract(p/4.0)-.5);
	float seams=smoothstep(.483,.498,max(tiles.x,tiles.y));
	vec3 concrete=vec3(.265,.275,.26)+(wear-.5)*.035-seams*.045;
	vec3 ground=mix(earth,concrete,paved)+(fine-.5)*.025;
	float grass=noise(p*.19)*noise(p*.047+18.0);
	ground=mix(ground,vec3(.135,.18,.095),smoothstep(.24,.60,grass)*(1.0-paved)*.55);
	float stains=smoothstep(.48,.75,noise(p*.21+71.0))*noise(p*.71);
	ground*=1.0-stains*paved*.2;
	float cracks=(1.0-smoothstep(.014,.048,abs(sin(p.x*.83+noise(p*.38)*3.0))))*
		smoothstep(.57,.76,noise(p*.34));
	ground*=1.0-cracks*paved*.22;
	float nearest=1000.0;float markings=0.0;float crossing=0.0;
	for(int i=0;i<8;i++) {
		if(i>=road_count) { break; }
		vec2 a=roads[i].xy;vec2 b=roads[i].zw;vec2 axis=b-a;
		float len=length(axis);float along=dot(p-a,axis)/len;
		float dist=length(p-(a+axis*clamp(along/len,0.0,1.0)));
		nearest=min(nearest,dist);
		crossing+=1.0-smoothstep(road_half_width+1.0,road_half_width+1.2,dist);
		float ends=smoothstep(3.0,5.0,min(along,len-along));
		markings=max(markings,(1.0-smoothstep(.05,.10,dist))*step(.4,fract(along/5.0))*ends);
	}
	// Slightly crumbled asphalt edges blend into the verge.
	float road_edge=nearest+(noise(p*1.3)-.5)*.3;
	float road=1.0-smoothstep(road_half_width-.15,road_half_width+.1,road_edge);
	float curb=(1.0-smoothstep(.035,.10,abs(nearest-road_half_width-.18)))*paved;
	float shoulder=(1.0-smoothstep(road_half_width+.3,road_half_width+1.1,road_edge))*(1.0-road);
	float side_line=1.0-smoothstep(.045,.075,abs(nearest-road_half_width+.45));
	vec3 asphalt=vec3(.078,.093,.097)+fine*.015+wear*.013;
	float repairs=smoothstep(.72,.80,noise(floor(p*.20)+33.0));
	asphalt*=1.0-repairs*.2;
	asphalt=mix(asphalt,vec3(.18,.18,.14),smoothstep(road_half_width-1.0,road_half_width,nearest)*wear*.24);
	markings*=1.0-smoothstep(1.15,1.65,crossing);
	asphalt=mix(asphalt,vec3(.58,.49,.30),max(markings,side_line*.5)*(.55+wear*.35));
	ground=mix(ground,vec3(.31,.32,.30),shoulder*.7);
	vec3 surface=mix(ground,asphalt,road)+curb*.065;
	// Flush loading aprons and the control yard stay part of the same surface.
	for(int i=0;i<3;i++) {
		vec2 center=i==0?vec2(76.0,26.0):(i==1?vec2(76.0,90.0):vec2(124.0,58.0));
		vec2 half_size=i<2?vec2(6.5,6.0):vec2(9.0);
		vec2 local=p-center;
		vec2 bounds=abs(local)-half_size;
		float inside=1.0-smoothstep(-.04,.04,max(bounds.x,bounds.y));
		vec3 apron=mix(vec3(.235,.22,.19),vec3(.29,.285,.26),wear);
		apron-=seams*.04;
		float edge=1.0-smoothstep(.10,.18,abs(abs(local.x)-half_size.x+.4));
		float hatching=step(.45,fract((local.x+local.y)*.6));
		float loading=step(half_size.x-1.4,abs(local.x))*hatching;
		apron=mix(apron,vec3(.58,.45,.22),max(edge,loading*.6)*(.48+.28*wear));
		float tire=(1.0-smoothstep(.15,.27,abs(abs(local.x)-2.1)))*(.15+.10*noise(p*.7));
		apron*=1.0-tire;
		surface=mix(surface,apron,inside);
		paved=max(paved,inside);
	}
	float puddle=smoothstep(.30,.58,noise(p*.34+3.0))*wetness*max(road,paved*.65);
	// Yards and aprons take concrete, roads the asphalt scan; puddles flatten both.
	TerrainSurface terrain=terrain_surface(p,surface,road,paved,.95);
	terrain.slope*=1.0-puddle*.78;
	ALBEDO=terrain.albedo*(1.0-wetness*.24);
	ROUGHNESS=mix(terrain.roughness*mix(1.0,.52,wetness),.05,puddle);
	AO=terrain.occlusion;
	NORMAL=terrain_normal(terrain,NORMAL,VIEW_MATRIX,INV_VIEW_MATRIX);
	SPECULAR=.24+wetness*.28;
}
