#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba32f, set = 0, binding = 0) uniform readonly image2D previous_state;
layout(rgba32f, set = 0, binding = 1) uniform writeonly image2D next_state;
layout(rgba32f, set = 0, binding = 2) uniform writeonly image2D visible_state;
layout(rgba32f, set = 0, binding = 3) uniform readonly image2D flow_field;
layout(std430, set = 0, binding = 4) readonly buffer Sources { vec4 impulses[]; } sources;
layout(push_constant, std430) uniform Params {
    vec4 region; // world origin.xy, span, dt
    vec4 map; // map size.xy, impulse count, reset
    vec4 scroll; // old-image offset.xy, unused.zw
} params;

vec4 flow_at(vec2 world) {
    ivec2 size = imageSize(flow_field);
    ivec2 p = ivec2(floor(world / params.map.xy * vec2(size)));
    if (any(lessThan(p, ivec2(0))) || any(greaterThanEqual(p, size))) return vec4(0);
    return imageLoad(flow_field, p);
}
vec4 state_at(ivec2 p) {
    if (params.map.w > .5) return vec4(0);
    p += ivec2(params.scroll.xy);
    if (any(lessThan(p, ivec2(0))) || any(greaterThanEqual(p, imageSize(previous_state)))) return vec4(0);
    return imageLoad(previous_state, p);
}
vec4 advect(vec2 p) {
    ivec2 i = ivec2(floor(p));
    vec2 f = fract(p);
    return mix(mix(state_at(i), state_at(i + ivec2(1,0)), f.x),
               mix(state_at(i + ivec2(0,1)), state_at(i + ivec2(1,1)), f.x), f.y);
}
float neighbor(ivec2 p, vec2 world, float center) {
    // Reflect at dry cells; banks and islands don't transmit ripples.
    return flow_at(world).a > .5 ? state_at(p).r : center;
}
void main() {
    ivec2 p = ivec2(gl_GlobalInvocationID.xy);
    ivec2 size = imageSize(previous_state);
    if (any(greaterThanEqual(p, size))) return;
    float dx = params.region.z / float(size.x);
    float dt = params.region.w;
    vec2 world = params.region.xy + (vec2(p) + .5) * dx;
    vec4 flow = flow_at(world);
    vec4 result = vec4(0);
    if (flow.a > .5) {
        vec4 old = advect(vec2(p) - flow.rg * dt / dx);
        float h = state_at(p).r;
        float lap = neighbor(p + ivec2(1,0), world + vec2(dx,0), h)
                  + neighbor(p - ivec2(1,0), world - vec2(dx,0), h)
                  + neighbor(p + ivec2(0,1), world + vec2(0,dx), h)
                  + neighbor(p - ivec2(0,1), world - vec2(0,dx), h) - 4.0 * h;
        // Linear shallow-water height/vertical-velocity model: c² = g * depth.
        // dt=1/30, dx=.5, depth<=1.2 satisfies the 2D CFL stability bound.
        float v = (old.g + 9.81 * flow.b * lap / (dx * dx) * dt) * exp(-1.7 * dt);
        float height = old.r + v * dt;
        float injected = 0.0;
        for (int i = 0; i < int(params.map.z); i++) {
            vec4 impulse = sources.impulses[i];
            float d = length(world - impulse.xy) / impulse.z;
            // Balanced central depression/ring reduces long-lived DC offsets.
            float pulse = (1.0 - d*d) * exp(-d*d);
            height += pulse * impulse.w;
            injected += exp(-2.0*d*d) * abs(impulse.w) * 4.0;
        }
        // Absorbing rim makes camera-local simulation disappear gently.
        float edge = min(min(float(p.x), float(p.y)), min(float(size.x-1-p.x), float(size.y-1-p.y)));
        float absorb = mix(.8, 1.0, smoothstep(0.0, 10.0, edge));
        float foam = clamp(old.b * exp(-.65*dt) + injected + max(abs(v)-.25, 0.0)*dt*.2, 0.0, 1.0);
        result = vec4(clamp(height, -.25, .25)*absorb, clamp(v, -3.0, 3.0)*absorb, foam*absorb, 1);
    }
    imageStore(next_state, p, result);
    imageStore(visible_state, p, result);
}
