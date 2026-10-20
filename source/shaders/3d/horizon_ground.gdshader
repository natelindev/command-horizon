shader_type spatial;
#include "res://source/shaders/3d/terrain_layers.gdshaderinc"
varying vec3 world_position;
uniform vec4 roads[8];
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1)), f.x), f.y);
}
float patch(vec2 p, vec2 center, vec2 extent) {
	vec2 d = abs(p - center) - extent;
	return 1.0 - smoothstep(-1.0, 1.2, max(d.x, d.y));
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz;
	float broad = noise(p * 0.045) * .6 + noise(p * .16) * .4;
	float grit = noise(p * 4.0);
	// Sub-pixel grain fades to its mean instead of shimmering at battle zoom.
	float grain = mix(.5, hash(floor(p * 22.0)), 1.0 - smoothstep(.5, 1.5, length(fwidth(p)) * 22.0));
	vec3 dust = mix(vec3(.205,.187,.146), vec3(.255,.237,.191), broad);
	vec3 gravel = mix(vec3(.145,.16,.144), vec3(.205,.214,.18), grit);
	float verge = 1.0 - smoothstep(5.0, 15.0, abs(p.x - 116.0) + noise(p*.3)*4.0);
	vec3 soil = mix(dust, gravel, clamp(verge*.8 + smoothstep(.49,.70,broad)*.3, 0.0,1.0));
	float apron = max(patch(p, vec2(25,65), vec2(22,22)), patch(p,vec2(157,65),vec2(20,23)));
	apron = max(apron,patch(p,vec2(76,66),vec2(12,11)));
	vec2 tile = abs(fract(p / 5.0)-.5);
	float seam = smoothstep(.482,.499,max(tile.x,tile.y));
	vec3 concrete = vec3(.235,.245,.215) + (grit-.5)*.026 - seam*.06;
	float stain = smoothstep(.40,.8,noise(p*.2))*.018;
	vec3 ground = mix(soil, concrete, apron) + (grain-.5)*.025 - stain;
	float cracks = (1.0-smoothstep(.015,.045,abs(sin(p.x*.81+noise(p*.35)*3.0))))
		* smoothstep(.58,.77,noise(p*.32));
	ground *= 1.0-cracks*apron*.22;
	float ripples = sin(p.x*2.6+p.y*.65+noise(p*.12)*5.0)*.5+.5;
	ground += (ripples-.5)*.009*(1.0-apron);
	float yards = max(patch(p,vec2(206,49),vec2(13,11)),patch(p,vec2(206,87),vec2(13,11)));
	ground = mix(ground,concrete,yards);
	float nearest = 1000.0;
	float paint = 0.0;
	float crossing = 0.0;
	for (int i = 0; i < 8; i++) {
		vec2 a = roads[i].xy; vec2 b = roads[i].zw;
		vec2 axis = b-a; float length_m = length(axis);
		float along = dot(p-a,axis) / length_m;
		vec2 closest = a + axis * clamp(along / length_m,0.0,1.0);
		float distance_m = length(p-closest);
		nearest = min(nearest,distance_m);
		crossing += 1.0-smoothstep(4.5,4.8,distance_m);
		float ends = smoothstep(3.0,5.0,min(along,length_m-along));
		float dash = (1.0-smoothstep(.065,.12,distance_m)) * step(.42,fract(along/5.0));
		paint = max(paint, dash * ends);
	}
	// Slightly crumbled asphalt edges blend into the verge.
	float road_edge = nearest + (noise(p * 1.3) - .5) * .35;
	float road = 1.0-smoothstep(3.85,4.25,road_edge);
	float shoulders = (1.0-smoothstep(4.1,5.2,road_edge))*(1.0-road);
	float side_line = (1.0-smoothstep(.04,.08,abs(nearest-3.35)));
	vec3 asphalt = vec3(.075,.091,.087)+grain*.018 + noise(p*.3)*.018;
	float repairs = smoothstep(.73,.81,noise(p*.32+33.0));
	asphalt *= 1.0-repairs*.16;
	float wear = smoothstep(.22,.6,noise(p*2.0));
	paint *= 1.0-smoothstep(1.15,1.8,crossing);
	asphalt = mix(asphalt,vec3(.40,.335,.20),max(paint,side_line*.65)*wear*.65);
	ground = mix(ground,vec3(.23,.215,.172),shoulders*.5);
	vec3 surface = mix(ground,asphalt,road);
	// Flush deployment/command markings replace raised decorative boxes.
	for(int i=0; i<2; i++) {
		vec2 local = p-(i==0?vec2(76,66):vec2(156,65));
		float side = (1.0-smoothstep(.07,.13,abs(abs(local.x)-9.0)))
			*(1.0-smoothstep(8.4,8.5,abs(local.y)));
		float ends = (1.0-smoothstep(.07,.13,abs(abs(local.y)-7.0)))
			*(1.0-smoothstep(7.0,7.1,abs(local.x)))*step(.6,fract((local.x+7.0)/2.0));
		float tires = (1.0-smoothstep(.15,.27,abs(abs(local.x)-2.1)))
			*patch(local,vec2(0),vec2(5,6));
		surface *= 1.0-tires*.14;
		surface = mix(surface,vec3(.47,.38,.20),max(side,ends)*(.5+wear*.25));
	}
	// Command aprons and yards take concrete; roads the asphalt scan.
	TerrainSurface terrain = terrain_surface(p, surface, road, max(apron, yards), .95);
	ALBEDO = terrain.albedo;
	ROUGHNESS = terrain.roughness;
	AO = terrain.occlusion;
	NORMAL = terrain_normal(terrain, NORMAL, VIEW_MATRIX, INV_VIEW_MATRIX);
}
