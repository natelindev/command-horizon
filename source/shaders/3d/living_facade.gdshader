shader_type spatial;
uniform vec4 masonry : source_color = vec4(.38,.36,.30,1.0);
uniform float night = 0.0;
uniform float wetness = 0.0;
uniform vec2 floors = vec2(4.0, 3.0);
uniform vec3 building_size = vec3(6.0,6.0,6.0);
varying vec3 world;
varying vec3 local;
varying vec3 local_normal;
float hash(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; local=VERTEX/building_size+.5; local_normal=NORMAL;}
void fragment(){
	vec2 facade_uv=vec2(abs(local_normal.x)>.5 ? local.z : local.x,local.y);
	vec2 cell=fract(facade_uv*floors);
	float window=step(.22,cell.x)*step(cell.x,.72)*step(.28,cell.y)*step(cell.y,.76)*(1.0-step(.5,abs(local_normal.y)));
	float lit=step(.30,hash(floor(facade_uv*floors)));
	float grain=hash(floor(world.xz*38.0)+floor(world.y*20.0));
	vec3 stone=masonry.rgb*(.90+grain*.15);
	float course=step(.965,fract(facade_uv.y*floors.y));
	stone*=1.0-course*.24;
	ALBEDO=mix(stone,vec3(.075,.13,.16),window);
	ROUGHNESS=mix(.88,.26,window)*mix(1.0,.6,wetness);
	METALLIC=window*.25;
	EMISSION=vec3(1.0,.57,.23)*window*lit*night*1.7;
}
