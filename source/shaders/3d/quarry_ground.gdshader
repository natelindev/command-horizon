shader_type spatial;
uniform bool exterior = false;
uniform vec4 roads[4];
uniform vec2 pads[2];
uniform vec2 sites[2];
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float rectangle(vec2 q, vec2 extent) { vec2 d=abs(q)-extent; return max(d.x,d.y); }
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec2 p=world_position.xz;
 float broad=noise(p*.07), wear=noise(p*.45), grit=noise(p*8.0);
 vec3 soil=mix(vec3(.20,.24,.235),vec3(.32,.33,.285),broad);
 soil+=(wear-.5)*.04+(grit-.5)*.022;
 float cut=1.0-smoothstep(4.0,12.0,abs(p.x-66.0));
 cut*=1.0-smoothstep(23.0,32.0,abs(p.y-51.0));
 vec3 color=mix(soil,vec3(.27,.295,.28)+(wear-.5)*.05,cut*.8);
 if(!exterior) {
  float nearest=1000.0;
  for(int i=0;i<4;i++) {
   vec2 a=roads[i].xy,v=roads[i].zw-a;
   float t=clamp(dot(p-a,v)/dot(v,v),0.0,1.0);
   nearest=min(nearest,length(p-a-v*t));
  }
  float road=1.0-smoothstep(3.35,3.9,nearest+(wear-.5)*.25);
  float shoulder=1.0-smoothstep(3.7,5.1,nearest);
  color=mix(color,vec3(.30,.32,.29),shoulder*.45);
  vec3 pavement=vec3(.125,.155,.155)+(wear-.5)*.026+(grit-.5)*.014;
  float edge=1.0-smoothstep(.04,.09,abs(nearest-3.05));
  pavement=mix(pavement,vec3(.58,.51,.31),edge*smoothstep(.2,.6,wear)*.62);
  color=mix(color,pavement,road);
  for(int i=0;i<2;i++) {
   vec2 q=p-pads[i];
   float apron=1.0-smoothstep(.0,.5,rectangle(q,vec2(6.5,6.0)));
   float border=1.0-smoothstep(.07,.12,abs(rectangle(q,vec2(5.6,5.1))));
   float cross=max((1.0-smoothstep(.18,.23,abs(q.x)))*step(abs(q.y),2.0),
      (1.0-smoothstep(.18,.23,abs(q.y)))*step(abs(q.x),2.0));
   vec2 joint=abs(fract(q/3.0)-.5);
   float seam=smoothstep(.485,.499,max(joint.x,joint.y));
   vec3 concrete=vec3(.24,.275,.27)+(wear-.5)*.024-seam*.025;
   concrete=mix(concrete,vec3(.65,.59,.37),border*.7);
   concrete=mix(concrete,vec3(.67,.70,.64),cross*.85);
   color=mix(color,concrete,apron);
   float site=1.0-smoothstep(0.0,.6,rectangle(p-sites[i],vec2(4.5)));
   color=mix(color,vec3(.30,.325,.30)+(wear-.5)*.035,site);
  }
  float flight_line=(1.0-smoothstep(.09,.15,abs(p.y-52.0)))*step(80.0,p.x)*step(p.x,116.0);
  flight_line*=step(3.8,mod(p.x-80.0,7.0));
  color=mix(color,vec3(.64,.56,.32),flight_line*.65);
 }
 ALBEDO=color;
 ROUGHNESS=.95;
}
