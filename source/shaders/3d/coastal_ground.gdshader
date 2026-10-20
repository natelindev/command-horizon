shader_type spatial;
#include "res://source/shaders/3d/terrain_layers.gdshaderinc"
uniform float layout_scale = 1.0;
varying vec3 world_position;
uniform vec4 roads[8];
uniform int road_count = 7;
uniform bool exterior = false;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float box_mask(vec2 p,vec2 center,vec2 extent,float fade) {
	vec2 d=abs(p-center)-extent;
	return 1.0-smoothstep(0.0,fade,max(d.x,d.y));
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p=world_position.xz / layout_scale;
	// Sub-pixel grain fades to its mean instead of shimmering at battle zoom.
	float fine=mix(.5,hash(floor(p*26.0)),1.0-smoothstep(.5,1.5,length(fwidth(p))*26.0));
	float wear=noise(p*.28);
	float turf=noise(p*.075)*.60+noise(p*.31)*.27+noise(p*.9)*.13;
	float grit=smoothstep(.54,.77,noise(p*.43+vec2(12.3,8.1)));
	vec3 earth=mix(vec3(.17,.205,.145),vec3(.225,.245,.18),smoothstep(.25,.72,turf));
	earth=mix(earth,vec3(.30,.305,.26),grit*.20);
	float coast_turf=(1.0-smoothstep(16.0,30.0,p.y))*(.60+noise(p*.12)*.4);
	earth=mix(earth,vec3(.34,.335,.255),coast_turf);
	float center=1.0-smoothstep(35.0,42.0,abs(p.x-64.0));
	float inland=smoothstep(46.0,54.0,p.y)*(1.0-smoothstep(97.0,102.0,p.y));
	float quay=(1.0-smoothstep(11.0,17.0,abs(p.x-64.0)-16.0))*(1.0-smoothstep(60.0,64.0,p.y));
	float paved=max(center*inland,quay);
	if(exterior) {
		paved=max(box_mask(p,vec2(32,121),vec2(7.3,6.0),1.8),box_mask(p,vec2(95,123),vec2(8,6.7),1.8));
		paved=max(paved,box_mask(p,vec2(64,130),vec2(6.5,6),1.8));
		paved=max(paved,box_mask(p,vec2(-12,34),vec2(6,5.5),1.5));
		paved=max(paved,box_mask(p,vec2(144,68),vec2(6.5,6),1.5));
	}
	vec2 tiles=abs(fract((p+vec2(.4,1.3))/4.0)-.5);
	float seams=smoothstep(.482,.496,max(tiles.x,tiles.y));
	float slab_variation=hash(floor((p+vec2(.4,1.3))/4.0))-.5;
	float stains=noise(p*.11+vec2(37,16))*.55+noise(p*.69)*.45;
	vec3 concrete=vec3(.315,.34,.32)+(wear-.5)*.045+slab_variation*.025-seams*.035;
	concrete-=smoothstep(.58,.80,stains)*vec3(.042,.038,.028);
	float oil=0.0;
	for(int i=0;i<2;i++) {
		vec2 crane=vec2(i==0 ? 42.0:86.0,30.0);
		vec2 foundry=vec2(i==0 ? 54.0:74.0,80.0);
		oil=max(oil,box_mask(p,crane+vec2(-2,1),vec2(2.0,3.0),2.1));
		oil=max(oil,box_mask(p,foundry+vec2(0,-5),vec2(3.9,1.0),1.7));
	}
	concrete-=oil*smoothstep(.33,.73,noise(p*.85))*vec3(.06,.063,.052);
	vec3 ground=mix(earth,concrete,paved)+(fine-.5)*.018;
	float nearest=1000.0; float markings=0.0; float crossing=0.0;
	for(int i=0;i<8;i++) {
		if(i>=road_count) { break; }
		vec2 a=roads[i].xy; vec2 b=roads[i].zw; vec2 axis=b-a;
		float len=length(axis); float along=dot(p-a,axis)/len;
		float distance=length(p-(a+axis*clamp(along/len,0.0,1.0)));
		nearest=min(nearest,distance);
		crossing+=1.0-smoothstep(5.0,5.2,distance);
		float ends=smoothstep(3.0,5.0,min(along,len-along));
		markings=max(markings,(1.0-smoothstep(.05,.10,distance))*step(.4,fract(along/5.0))*ends);
	}
	// Slightly crumbled asphalt edges blend into the verge.
	float road_edge=nearest+(noise(p*1.3)-.5)*.35;
	float road=1.0-smoothstep(3.85,4.1,road_edge);
	float shoulder=(1.0-smoothstep(4.3,5.1,road_edge))*(1.0-road);
	float stripe=1.0-smoothstep(.045,.075,abs(nearest-3.55));
	float tires=1.0-smoothstep(.18,.47,abs(nearest-1.1));
	vec3 asphalt=vec3(.078,.102,.106)+fine*.010+wear*.018-tires*.009;
	markings*=1.0-smoothstep(1.15,1.65,crossing);
	asphalt=mix(asphalt,vec3(.63,.60,.43),max(markings,stripe*.40)*(.45+wear*.45));
	ground=mix(ground,vec3(.32,.34,.30),shoulder*.65);
	vec3 color=mix(ground,asphalt,road);
	float path=road;
	if(exterior || (p.y>=94.0 && abs(p.x-64.0)<4.0)) {
		// Narrow back-of-port service roads join the yards and utilities.
		float lane=abs(p.y-111.0);
		lane=max(lane,max(22.0-p.x,p.x-104.0));
		float spur=abs(p.x-64.0);
		spur=max(spur,max(94.0-p.y,p.y-129.0));
		float west=abs(p.x+12.0);
		west=max(west,max(20.0-p.y,p.y-46.0));
		float east=abs(p.x-144.0);
		east=max(east,max(44.0-p.y,p.y-80.0));
		float service=min(min(lane,spur),min(west,east));
		float access=(1.0-smoothstep(1.5,2.6,service))*(.82+noise(p*1.4)*.18);
		color=mix(color,asphalt+vec3(.045,.04,.025),access*.82);
		path=max(path,access*.82);
	}
	// Scans stay at physical scale when the layout is enlarged.
	TerrainSurface terrain=terrain_surface(world_position.xz,color,path,paved,.95);
	ALBEDO=terrain.albedo;
	ROUGHNESS=terrain.roughness;
	AO=terrain.occlusion;
	NORMAL=terrain_normal(terrain,NORMAL,VIEW_MATRIX,INV_VIEW_MATRIX);
}
