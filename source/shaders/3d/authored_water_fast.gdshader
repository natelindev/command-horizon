shader_type spatial;
render_mode cull_disabled, depth_draw_always;

// Non-refractive water variant: omits hint_screen_texture so Forward+ skips the
// full-screen mipmapped framebuffer copy while retaining depth absorption, ripples, and waves.
uniform vec4 deep : source_color = vec4(0.10, 0.20, 0.19, 1.0);
uniform vec4 shallow : source_color = vec4(0.32, 0.38, 0.30, 1.0);
uniform vec4 foam : source_color = vec4(0.82, 0.78, 0.68, 1.0);
uniform float clarity = 1.6;
uniform bool surface_effects = true;
uniform float simulation_time = 0.0;
uniform float flow_speed = 1.2;
uniform float wave_height = .065;
uniform bool has_flow_field = false;
uniform sampler2D flow_field : filter_linear, repeat_disable;
uniform vec2 flow_map_size = vec2(1.0);
uniform bool interactive_water = false;
uniform sampler2D ripple_state : filter_linear, repeat_disable;
uniform vec4 ripple_region = vec4(0.0, 0.0, 64.0, .5);
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying vec2 world_position;
varying float world_y;

float hash(vec2 p)
{
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 grad(vec2 i)
{
  float angle = hash(i) * 6.2831853;
  return vec2(cos(angle), sin(angle));
}

float gnoise(vec2 p)
{
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  float a = dot(grad(i), f);
  float b = dot(grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
  float c = dot(grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
  float d = dot(grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 0.5 + 0.5;
}

vec3 gnoise_d(vec2 p)
{
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
  vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
  vec2 ga = grad(i);
  vec2 gb = grad(i + vec2(1.0, 0.0));
  vec2 gc = grad(i + vec2(0.0, 1.0));
  vec2 gd = grad(i + vec2(1.0, 1.0));
  float va = dot(ga, f);
  float vb = dot(gb, f - vec2(1.0, 0.0));
  float vc = dot(gc, f - vec2(0.0, 1.0));
  float vd = dot(gd, f - vec2(1.0, 1.0));
  float k1 = vb - va;
  float k2 = vc - va;
  float k3 = va - vb - vc + vd;
  float val = (va + k1 * u.x + k2 * u.y + k3 * u.x * u.y) * 0.5 + 0.5;
  vec2 dval = 0.5 * (ga + (gb - ga) * u.x + (gc - ga) * u.y + (ga - gb - gc + gd) * u.x * u.y +
                     du * vec2(k1 + k3 * u.y, k2 + k3 * u.x));
  return vec3(val, dval);
}

float ripple_height(vec2 uv)
{
  return texture(ripple_state, uv).r;
}

float ripple_fade(vec2 uv)
{
  vec2 edge = min(uv, vec2(1.0) - uv);
  return smoothstep(0.0, .08, min(edge.x, edge.y));
}

vec2 surface_gradient(vec2 p, vec2 flow_vel, float t, float detail_fade)
{
  vec2 g = vec2(0.0);
  vec3 n1 = gnoise_d(p * 0.28);
  vec3 n2 = gnoise_d(p * 0.41 + 4.3);
  float s1 = cos(p.x * 1.15 + p.y * 0.45 + n1.x * 2.2) * 0.42;
  float s2 = cos(p.x * 1.65 - p.y * 1.25 + n2.x * 1.8) * 0.28;
  g += s1 * (vec2(1.15, 0.45) + n1.yz * (0.28 * 2.2));
  g += s2 * (vec2(1.65, -1.25) + n2.yz * (0.41 * 1.8));

  mat2 r1 = mat2(vec2(0.86, -0.51), vec2(0.51, 0.86));
  vec2 w1 = r1 * p;
  vec3 n3 = gnoise_d(w1 * 1.45 - vec2(t * 0.55, t * 0.22));
  g += (transpose(r1) * n3.yz) * (1.45 * 0.55);

  if (detail_fade > 0.01)
  {
    mat2 r2 = mat2(vec2(0.68, 0.73), vec2(-0.73, 0.68));
    vec2 w2 = r2 * p;
    vec3 n4 = gnoise_d(w2 * 2.35 + vec2(t * 0.42, -t * 0.35));
    g += (transpose(r2) * n4.yz) * (2.35 * 0.38 * detail_fade);

    float phase = fract(t * 0.16);
    vec2 scale = vec2(3.8, 3.2);
    vec2 a = (p - flow_vel * 0.35 * phase * 6.0) * scale;
    vec2 b = (p - flow_vel * 0.35 * fract(phase + 0.5) * 6.0) * scale;
    float w = abs(phase * 2.0 - 1.0);
    vec2 micro_g = mix(gnoise_d(a).yz, gnoise_d(b).yz, w) * scale;
    g += micro_g * (0.24 * detail_fade);
  }
  return g;
}

vec3 reconstruct_world(vec2 screen_uv, float depth_sample, mat4 inv_proj, mat4 inv_view)
{
  vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth_sample);
  if (CLIP_SPACE_FAR < 0.0)
  {
    ndc.z = depth_sample * 2.0 - 1.0;
  }
  vec4 view_pos = inv_proj * vec4(ndc, 1.0);
  view_pos.xyz /= view_pos.w;
  return (inv_view * vec4(view_pos.xyz, 1.0)).xyz;
}

void vertex()
{
  vec4 world_v = MODEL_MATRIX * vec4(VERTEX, 1.0);
  world_position = world_v.xz;
  if (surface_effects)
  {
    float downstream = UV.x - simulation_time * flow_speed;
    if (interactive_water)
    {
      vec2 local_uv = (world_position - ripple_region.xy) / ripple_region.z;
      VERTEX.y += ripple_height(local_uv) * ripple_fade(local_uv);
    }
    VERTEX.y += wave_height * COLOR.r *
        (sin(downstream * 1.6 + UV.y * 0.55) * 0.6 + sin(downstream * 2.7 - UV.y * 1.1) * 0.4);
  }
  world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment()
{
  float depth_raw = textureLod(depth_texture, SCREEN_UV, 0.0).r;
  vec3 behind_world = reconstruct_world(SCREEN_UV, depth_raw, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
  float water_depth = max(0.0, world_y - behind_world.y);
  float edge_alpha = smoothstep(0.0, 0.12, water_depth);

  float optical_depth = water_depth / max(clarity, 0.4);
  float absorb = 1.0 - exp(-optical_depth * 2.35);
  vec3 water_tint = mix(shallow.rgb, deep.rgb, smoothstep(0.08, 0.85, absorb));

  vec4 field = has_flow_field
      ? texture(flow_field, world_position / flow_map_size)
      : vec4(normalize(UV2) * flow_speed, 1.0, 1.0);
  vec2 velocity = has_flow_field ? field.rg : normalize(UV2) * flow_speed;
  float speed = length(velocity);
  vec2 direction = speed > 0.01 ? velocity / speed : normalize(UV2);
  vec2 across = vec2(-direction.y, direction.x);

  vec2 slope = vec2(0.0);
  float shore_foam = 0.0;
  float local_foam = 0.0;
  float t = simulation_time;

  if (surface_effects)
  {
    float pixel_footprint = max(length(dFdx(world_position)), length(dFdy(world_position)));
    float detail_fade = 1.0 - smoothstep(0.08, 0.28, pixel_footprint);

    vec2 flow_coords = vec2(UV.x - t * flow_speed * 0.65, UV.y);
    vec2 local_grad = surface_gradient(flow_coords, velocity, t, detail_fade);
    slope = (direction * local_grad.x + across * local_grad.y) * 0.105;

    if (interactive_water)
    {
      vec2 local_uv = (world_position - ripple_region.xy) / ripple_region.z;
      vec2 pixel = vec2(ripple_region.w / ripple_region.z, 0.0);
      float fade = ripple_fade(local_uv);
      slope += vec2(
                   ripple_height(local_uv + pixel.xy) - ripple_height(local_uv - pixel.xy),
                   ripple_height(local_uv + pixel.yx) - ripple_height(local_uv - pixel.yx)) /
          (2.0 * ripple_region.w) * fade * 1.15;
      local_foam = texture(ripple_state, local_uv).b * fade;
    }

    float shore_band = (1.0 - smoothstep(0.02, 0.24, water_depth)) * smoothstep(0.0, 0.03, water_depth);
    float lap_wave = sin(water_depth * 24.0 - t * 2.1 + gnoise(world_position * 1.3) * 4.2);
    float lacy = smoothstep(0.38, 0.72, gnoise(world_position * 2.8 - velocity * t * 0.4));
    shore_foam = shore_band * smoothstep(0.1, 0.85, lap_wave) * lacy * 0.55;
  }

  vec3 view_normal = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
  NORMAL = view_normal;

  float ndotv = clamp(dot(view_normal, VIEW), 0.0, 1.0);
  float fresnel = 0.02 + 0.98 * pow(1.0 - ndotv, 5.0);
  vec3 sky_sheen = mix(shallow.rgb * 0.85 + vec3(0.08, 0.14, 0.18), vec3(0.56, 0.68, 0.75), 0.55);

  float foam_amount = clamp(shore_foam + local_foam * 0.75, 0.0, 0.85);
  vec3 surface_color = mix(water_tint, sky_sheen, fresnel * (surface_effects ? 0.36 : 0.18));
  ALBEDO = mix(surface_color, foam.rgb, foam_amount);
  float water_opacity = clamp(0.24 + absorb * 0.72, 0.0, 0.96);
  ALPHA = edge_alpha * mix(water_opacity, 1.0, foam_amount);
  ROUGHNESS = surface_effects ? mix(0.32, 0.50, foam_amount) : 0.46;
  SPECULAR = surface_effects ? 0.18 : 0.14;
  METALLIC = 0.0;
}
