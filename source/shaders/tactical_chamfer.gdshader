shader_type canvas_item;

uniform vec2 rect_size = vec2(380.0, 56.0);
uniform float cut_size = 12.0;
uniform bool cut_top_right = true;
uniform bool cut_bottom_left = true;
uniform bool cut_top_left = false;
uniform bool cut_bottom_right = false;
uniform float border_width = 1.4;
uniform float left_accent_width = 4.0;
uniform vec4 bg_color : source_color = vec4(0.08, 0.11, 0.15, 0.92);
uniform vec4 bg_bottom : source_color = vec4(0.04, 0.06, 0.08, 0.94);
uniform vec4 border_color : source_color = vec4(0.28, 0.36, 0.44, 0.88);
uniform vec4 accent_color : source_color = vec4(0.91, 0.69, 0.29, 1.0);
uniform float hover_glow : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.025;
uniform bool is_primary = false;

void fragment() {
    vec2 pos = UV * rect_size;
    float d_left = pos.x;
    float d_right = rect_size.x - pos.x;
    float d_top = pos.y;
    float d_bottom = rect_size.y - pos.y;

    float d = min(min(d_left, d_right), min(d_top, d_bottom));

    if (cut_top_right) {
        float d_tr = ((rect_size.x - pos.x) + pos.y - cut_size) * 0.70710678;
        d = min(d, d_tr);
    }
    if (cut_bottom_left) {
        float d_bl = (pos.x + (rect_size.y - pos.y) - cut_size) * 0.70710678;
        d = min(d, d_bl);
    }
    if (cut_top_left) {
        float d_tl = (pos.x + pos.y - cut_size) * 0.70710678;
        d = min(d, d_tl);
    }
    if (cut_bottom_right) {
        float d_br = ((rect_size.x - pos.x) + (rect_size.y - pos.y) - cut_size) * 0.70710678;
        d = min(d, d_br);
    }

    float edge_aa = smoothstep(-0.8, 0.2, d);
    if (edge_aa <= 0.0) {
        discard;
    }

    // Vertical machined gradient + subtle diagonal specular sheen.
    vec4 grad = mix(bg_color, bg_bottom, smoothstep(0.0, 1.0, UV.y));
    float diag = exp(-pow((UV.x * 0.75 + UV.y * 0.5 - 0.25) * 2.8, 2.0));
    grad.rgb += vec3(0.04, 0.045, 0.05) * diag;

    // 3D beveled lighting: crisp upper highlight and dark lower shadow lip.
    float top_bevel = smoothstep(4.5, 0.8, pos.y) * smoothstep(0.4, 1.8, d);
    float bottom_shadow = smoothstep(5.0, 0.8, rect_size.y - pos.y) * smoothstep(0.4, 1.8, d);
    grad.rgb += vec3(0.11, 0.12, 0.13) * top_bevel;
    grad.rgb -= vec3(0.06, 0.07, 0.08) * bottom_shadow;

    // Hover & primary radiant fill.
    float glow_mix = is_primary ? (0.35 + hover_glow * 0.55) : hover_glow;
    vec4 active_bg = grad + vec4(accent_color.rgb * (0.14 * glow_mix), 0.0);
    // Subtle top-down accent wash on hover or primary.
    float top_wash = exp(-pos.y / max(10.0, rect_size.y * 0.45));
    active_bg.rgb = mix(active_bg.rgb, accent_color.rgb, top_wash * (is_primary ? 0.22 : 0.14 * hover_glow));

    // Outer dark housing + crisp metallic/luminous border.
    float is_outer_rim = 1.0 - smoothstep(0.0, 1.0, d);
    float is_border = (1.0 - smoothstep(0.8, 0.8 + border_width, d)) * (1.0 - is_outer_rim);
    vec4 lit_border = mix(border_color, accent_color * 1.15, is_primary ? 0.65 + hover_glow * 0.35 : hover_glow * 0.85);
    vec4 col = mix(active_bg, lit_border, is_border);
    col = mix(col, vec4(0.015, 0.02, 0.025, 0.96), is_outer_rim);

    // Left luminous accent bar + soft inner bloom.
    if (left_accent_width > 0.0 && d > 1.0) {
        if (pos.x < left_accent_width) {
            vec4 bar_col = mix(accent_color * 0.72, accent_color * 1.2, hover_glow);
            col = mix(col, bar_col, 0.92);
        } else if (pos.x < left_accent_width + 14.0) {
            float bloom = 1.0 - (pos.x - left_accent_width) / 14.0;
            col.rgb += accent_color.rgb * bloom * bloom * (0.12 + 0.18 * hover_glow);
        }
    }

    // Subtle precision scanlines.
    if (scanline_strength > 0.0) {
        float scanline = sin(pos.y * 3.14159) * scanline_strength;
        col.rgb += scanline * (1.0 - is_border - is_outer_rim);
    }

    COLOR = vec4(col.rgb, col.a * edge_aa);
}
