shader_type canvas_item;

uniform vec2 rect_size = vec2(380.0, 56.0);
uniform float cut_size = 12.0;
uniform bool cut_top_right = true;
uniform bool cut_bottom_left = true;
uniform bool cut_top_left = false;
uniform bool cut_bottom_right = false;
uniform float border_width = 1.2;
uniform float left_accent_width = 4.0;
uniform vec4 bg_color : source_color = vec4(0.06, 0.09, 0.12, 0.94);
uniform vec4 border_color : source_color = vec4(0.18, 0.27, 0.33, 0.85);
uniform vec4 accent_color : source_color = vec4(0.85, 0.67, 0.28, 1.0);
uniform float hover_glow : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_strength : hint_range(0.0, 0.2) = 0.03;

void fragment() {
    vec2 pos = UV * rect_size;
    float d_left = pos.x;
    float d_right = rect_size.x - pos.x;
    float d_top = pos.y;
    float d_bottom = rect_size.y - pos.y;
    
    float d = min(min(d_left, d_right), min(d_top, d_bottom));
    
    // Top-right 45-degree chamfer
    if (cut_top_right) {
        float d_tr = ((rect_size.x - pos.x) + pos.y - cut_size) * 0.70710678;
        d = min(d, d_tr);
    }
    
    // Bottom-left 45-degree chamfer
    if (cut_bottom_left) {
        float d_bl = (pos.x + (rect_size.y - pos.y) - cut_size) * 0.70710678;
        d = min(d, d_bl);
    }
    
    // Top-left 45-degree chamfer
    if (cut_top_left) {
        float d_tl = (pos.x + pos.y - cut_size) * 0.70710678;
        d = min(d, d_tl);
    }
    
    // Bottom-right 45-degree chamfer
    if (cut_bottom_right) {
        float d_br = ((rect_size.x - pos.x) + (rect_size.y - pos.y) - cut_size) * 0.70710678;
        d = min(d, d_br);
    }
    
    // Smooth anti-aliased perimeter edge
    float edge_aa = smoothstep(-0.8, 0.2, d);
    if (edge_aa <= 0.0) {
        discard;
    }
    
    // Interpolate border and background on hover
    vec4 active_border = mix(border_color, accent_color, hover_glow);
    vec4 active_bg = mix(bg_color, bg_color * 1.35 + vec4(accent_color.rgb * 0.12, 0.0), hover_glow);
    
    // Crisp border line
    float is_border = 1.0 - smoothstep(0.0, border_width, d);
    vec4 col = mix(active_bg, active_border, is_border);
    
    // Left vertical accent stripe
    if (pos.x < left_accent_width && d > 0.0) {
        col = mix(mix(border_color, accent_color * 0.6, 0.5), accent_color, hover_glow);
    }
    
    // Precision military subtle scanlines
    if (scanline_strength > 0.0) {
        float scanline = sin(pos.y * 3.14159) * scanline_strength;
        col.rgb += scanline * (1.0 - is_border);
    }
    
    COLOR = vec4(col.rgb, col.a * edge_aa);
}
