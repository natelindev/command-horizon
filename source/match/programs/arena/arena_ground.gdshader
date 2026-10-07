shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_point;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 grid = abs(fract(world_point.xz / 2.0 - 0.5) - 0.5);
    vec2 width = max(fwidth(world_point.xz / 2.0), vec2(0.001));
    float line = 1.0 - clamp(min(grid.x / width.x, grid.y / width.y), 0.0, 1.0);
    ALBEDO = mix(vec3(0.095, 0.13, 0.15), vec3(0.16, 0.20, 0.22), line * 0.6);
    ROUGHNESS = 0.95;
}
