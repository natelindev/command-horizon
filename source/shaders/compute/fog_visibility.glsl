#[compute]
#version 450
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;
layout(rgba8, set = 0, binding = 0) uniform image2D exploration;
layout(rgba8, set = 0, binding = 1) uniform image2D current_visibility;
layout(rgba8, set = 0, binding = 2) uniform image2D combined_visibility;
struct Primitive { vec4 ab; vec4 c_kind; };
layout(std430, set = 0, binding = 3) readonly buffer Primitives { Primitive shapes[]; };
layout(std430, set = 0, binding = 4) readonly buffer Ranges { uvec2 ranges[]; };
layout(std430, set = 0, binding = 5) readonly buffer Indices { uint indices[]; };
layout(push_constant, std430) uniform Parameters {
    ivec2 size;
    int columns;
    int pass_index;
    vec4 explored_color;
    vec4 visible_color; // alpha carries reveal-all; output is opaque.
} params;

float edge(vec2 a, vec2 b, vec2 p) {
    vec2 u = b - a;
    vec2 v = p - a;
    return u.x * v.y - u.y * v.x;
}
bool contains(Primitive shape, vec2 p) {
    if (shape.c_kind.z < 0.5) {
        vec2 delta = p - shape.ab.xy;
        return dot(delta, delta) <= shape.ab.z * shape.ab.z;
    }
    vec2 a = shape.ab.xy;
    vec2 b = shape.ab.zw;
    vec2 c = shape.c_kind.xy;
    if (abs(edge(a, b, c)) < 0.00001) return false;
    vec3 sides = vec3(edge(a, b, p), edge(b, c, p), edge(c, a, p));
    return all(greaterThanEqual(sides, vec3(-0.00001))) ||
        all(lessThanEqual(sides, vec3(0.00001)));
}
void main() {
    ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    if (any(greaterThanEqual(pixel, params.size))) return;
    if (params.pass_index == 0) {
        ivec2 tile = pixel / 16;
        uvec2 range = ranges[tile.y * params.columns + tile.x];
        bool visible = false;
        for (uint i = 0; i < range.y; ++i) {
            if (contains(shapes[indices[range.x + i]], vec2(pixel) + 0.5)) {
                visible = true;
                break;
            }
        }
        vec4 remembered = imageLoad(exploration, pixel);
        if (visible) {
            remembered = vec4(params.explored_color.rgb, 1.0);
            imageStore(exploration, pixel, remembered);
        }
        vec3 color = remembered.rgb;
        if (visible || params.visible_color.a > 0.5) color = params.visible_color.rgb;
        imageStore(current_visibility, pixel, vec4(color, 1.0));
    } else {
        // A small tent filter keeps the existing soft tactical fog boundary.
        vec3 color = vec3(0.0);
        for (int y = -1; y <= 1; ++y) {
            for (int x = -1; x <= 1; ++x) {
                float weight = float((x == 0 ? 2 : 1) * (y == 0 ? 2 : 1));
                ivec2 sample_pixel = clamp(pixel + ivec2(x, y), ivec2(0), params.size - 1);
                color += imageLoad(current_visibility, sample_pixel).rgb * weight;
            }
        }
        imageStore(combined_visibility, pixel, vec4(color / 16.0, 1.0));
    }
}
