shader_type spatial;

// Custom lighting model: Manual control over Light, Shadow, and Specular
render_mode 
    blend_mix, 
    cull_back, 
    depth_draw_opaque; 

uniform vec4 paint_color : hint_color = vec4(1.0);
// Damage marks (HullScorch), on by default; set damage_mark_strength = 0 for special surfaces.
// A hull that has been hit gets its own material copy with damage_active = 1 and the slots below,
// in the mesh's own space; shared materials (hulls never hit) skip all damage work.
// - Scars (char): damage_scar_N = (where the shot met the hit surface, radius), damage_scar_dir_N
//   = (shot direction, strength; 0 = unused slot). Surfaces within the radius of the shot line, from
//   damage_scar_reach_front before that point to damage_scar_reach_back behind it (at least the
//   radius either way), and facing the shot, blend to damage_mark_color (the cooled char).
// - Wear: a damage_wear share of the hull charred in blocky patches damage_wear_cell wide.
// - Heat: damage_heat_N = (point, radius), damage_heat_time_N = (hit time, heat then), worked out per
//   vertex; it cools over damage_cool_time against damage_time, the ship's clock.
// Slot counts match Constants.SCORCH_MAX_SCARS and SCORCH_HEAT_SLOTS. Keep in sync with the other solid shader.
uniform float damage_active = 0.0;
uniform vec4 damage_mark_color : hint_color = vec4(0.02, 0.02, 0.02, 1.0);
uniform float damage_mark_strength : hint_range(0.0, 1.0) = 1.0;
// Char shows as crisp, dithered patches: the mark is cut at damage_mark_edge, with a Bayer-dithered
// band damage_mark_softness wide.
uniform float damage_mark_edge : hint_range(0.0, 1.0) = 0.15;
uniform float damage_mark_softness : hint_range(0.0, 1.0) = 0.5;
// Blackbody ramp for the glow, coolest to hottest (heat is temperature).
uniform vec4 damage_dull_color : hint_color = vec4(0.35, 0.02, 0.0, 1.0);
uniform vec4 damage_hot_color : hint_color = vec4(1.0, 0.18, 0.03, 1.0);
uniform vec4 damage_orange_color : hint_color = vec4(1.0, 0.5, 0.12, 1.0);
uniform vec4 damage_white_color : hint_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float damage_max_heat = 3.0;  // Heat that reads white-hot; pushed from Constants.SCORCH_MAX_HEAT
uniform float damage_glow_strength = 1.5;
uniform float damage_cool_time = 6.0;  // Seconds for heat to fall to ~37%
uniform float damage_glow_threshold = 0.25;  // Heat below this does not glow (incandescence)
uniform float damage_time = 0.0;  // The ship's clock, set by HullScorch while the hull is hot
uniform float damage_scar_reach_front = 0.5;
uniform float damage_scar_reach_back = 3.0;
uniform float damage_facing_min = 0.05;
uniform float damage_wear = 0.0;
uniform float damage_wear_cell = 1.5;
uniform vec4 damage_scar_0 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_scar_1 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_scar_2 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_scar_3 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_scar_4 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_scar_5 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_scar_dir_0 = vec4(0.0);
uniform vec4 damage_scar_dir_1 = vec4(0.0);
uniform vec4 damage_scar_dir_2 = vec4(0.0);
uniform vec4 damage_scar_dir_3 = vec4(0.0);
uniform vec4 damage_scar_dir_4 = vec4(0.0);
uniform vec4 damage_scar_dir_5 = vec4(0.0);
uniform vec4 damage_heat_0 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_heat_1 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_heat_2 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 damage_heat_3 = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 damage_heat_time_0 = vec2(0.0);
uniform vec2 damage_heat_time_1 = vec2(0.0);
uniform vec2 damage_heat_time_2 = vec2(0.0);
uniform vec2 damage_heat_time_3 = vec2(0.0);
varying vec4 damage_pos;  // Mesh-space position; w = heat
varying vec3 damage_normal;  // Mesh-space normal

// Glow for a temperature above the incandescence threshold: dull red, red, orange, then
// yellow-white, brighter as it gets hotter.
vec3 damage_glow(float raw_heat) {
    float t = clamp((raw_heat - damage_glow_threshold) / max(damage_max_heat - damage_glow_threshold, 0.001), 0.0, 1.0);
    vec3 color = mix(damage_dull_color.rgb, damage_hot_color.rgb, smoothstep(0.0, 0.25, t));
    color = mix(color, damage_orange_color.rgb, smoothstep(0.25, 0.6, t));
    color = mix(color, damage_white_color.rgb, smoothstep(0.6, 1.0, t));
    return color * sqrt(t) * damage_glow_strength;
}

// Heat a spot gives a vertex now.
float damage_heat_spot(vec3 pos, vec4 spot, vec2 hit) {
    float heat = hit.y * exp(-max(damage_time - hit.x, 0.0) / damage_cool_time);
    return heat * (1.0 - smoothstep(0.0, spot.w, distance(pos, spot.xyz)));
}

// Char a scar leaves on a fragment: near the shot line, within reach of the hit, facing the shot.
float damage_scar_mark(vec3 pos, vec3 normal, vec4 scar, vec4 line) {
    vec3 rel = pos - scar.xyz;
    float along = dot(rel, line.xyz);
    float off_line = length(rel - line.xyz * along);
    float in_reach = step(-max(damage_scar_reach_front, scar.w), along) * step(along, max(damage_scar_reach_back, scar.w));
    float facing = step(dot(normal, line.xyz), -damage_facing_min);
    return line.w * in_reach * facing * (1.0 - smoothstep(0.0, scar.w, off_line));
}

// Wear: a damage_wear share of blocky cells is charred (hash of the cell, no texture).
float damage_wear_mark(vec3 pos) {
    vec3 p = fract(floor(pos / damage_wear_cell) * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return step(fract((p.x + p.y) * p.z) + 0.0001, damage_wear) * 0.8;
}

// All marks on a fragment, 0 (clean) to 1.
float damage_marks(vec3 pos, vec3 normal) {
    float clean = 1.0 - damage_scar_mark(pos, normal, damage_scar_0, damage_scar_dir_0);
    clean *= 1.0 - damage_scar_mark(pos, normal, damage_scar_1, damage_scar_dir_1);
    clean *= 1.0 - damage_scar_mark(pos, normal, damage_scar_2, damage_scar_dir_2);
    clean *= 1.0 - damage_scar_mark(pos, normal, damage_scar_3, damage_scar_dir_3);
    clean *= 1.0 - damage_scar_mark(pos, normal, damage_scar_4, damage_scar_dir_4);
    clean *= 1.0 - damage_scar_mark(pos, normal, damage_scar_5, damage_scar_dir_5);
    return max(1.0 - clean, damage_wear_mark(pos));
}

uniform sampler2D detail_texture : hint_albedo; // Green channel used for scratches/dirt
uniform sampler2D normal_texture : hint_normal;

uniform float detail_paint_scale = 1.0;
uniform float detail_paint_strength : hint_range(-1.0, 1.0) = 0.0; // Neg = Dark, Pos = Light
uniform float detail_paint_contrast : hint_range(0.1, 10.0) = 1.0;

uniform float detail_normal_scale = 1.0;
uniform float detail_normal_strength : hint_range(-5.0, 5.0) = 1.0;

uniform float rim_strength = 1.0;
uniform float rim_exponent = 3.0;
uniform float rim_intensity = 0.3;

// Fade start and end distances (for LOD discard dithering)
uniform float fade_start = 300000.0;
uniform float fade_end_mul = 5.0;
uniform float fade_power = 2.0;

// Dither threshold for distance fade
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;

// Dither and posterization constants
const float light_dither_strength = 0.5;
const float posterization_levels = 5.0;
const float dither_pixel_size = 2.0;

uniform float uv_triplanar_sharpness : hint_range(0.0, 100.0) = 10.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

varying vec3 uv_triplanar_pos;
varying vec3 uv_power_normal;

// --- Helper Functions ---

// Triplanar texture sampling
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_pos) {
    vec4 samp = vec4(0.0);
    samp += texture(p_sampler, p_pos.xy) * p_weights.z;
    samp += texture(p_sampler, p_pos.xz) * p_weights.y;
    samp += texture(p_sampler, p_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
    return samp;
}

// 2x2 Bayer matrix lookup via arithmetic
float bayer2x2(vec2 p) {
    return p.x * 2.0 + p.y * (3.0 - 4.0 * p.x);
}

// Fast GLES2-compatible 8x8 Bayer matrix calculation without stack array allocations
float bayer8x8(vec2 screen_pos) {
    vec2 p = mod(floor(screen_pos), 8.0);
    vec2 p0 = mod(p, 2.0);
    vec2 p1 = mod(floor(p / 2.0), 2.0);
    vec2 p2 = floor(p / 4.0);
    float val = 16.0 * bayer2x2(p0) + 4.0 * bayer2x2(p1) + bayer2x2(p2);
    return val / 64.0;
}

// --- Vertex Function ---
void vertex() {
    // Damage marks work in mesh space, before the far-distance scaling.
    damage_pos = vec4(VERTEX, 0.0);
    damage_normal = NORMAL;
    if (damage_active > 0.5) {
        float heat = damage_heat_spot(VERTEX, damage_heat_0, damage_heat_time_0);
        heat += damage_heat_spot(VERTEX, damage_heat_1, damage_heat_time_1);
        heat += damage_heat_spot(VERTEX, damage_heat_2, damage_heat_time_2);
        heat += damage_heat_spot(VERTEX, damage_heat_3, damage_heat_time_3);
        damage_pos.w = min(heat, damage_max_heat) * damage_mark_strength;
    }

	// Non-linear perspective
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
	
    // Standard TBN generation for Triplanar
    TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
    TANGENT = normalize(TANGENT);
    BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x);
    BINORMAL += vec3(0.0, 0.0, -1.0) * abs(NORMAL.y);
    BINORMAL += vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
    BINORMAL = normalize(BINORMAL);
    
    // Triplanar Weights
    uv_power_normal = pow(abs(NORMAL), vec3(uv_triplanar_sharpness));
    uv_power_normal /= dot(uv_power_normal, vec3(1.0));
    
    // World Position Mapping
    uv_triplanar_pos = VERTEX * uv_scale + uv_offset;
    uv_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

// --- Fragment Function ---
void fragment() {
    // Virtual pixel coordinates for DPI-independent dither grid
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
    float bayer = bayer8x8(dither_pos);

    // --- Distance-based LOD Discard Dithering ---
    float distance_vert = length(VERTEX);
    float fade_range = fade_end_mul * fade_start - fade_start;
    if (fade_range > 0.0 && distance_vert > fade_start) {
        float fade_factor = pow(clamp((fade_end_mul * fade_start - distance_vert) / fade_range, 0.0, 1.0), fade_power);
        if (fade_factor < bayer * dither_threshold + 1e-6) {
            discard;
        }
    }

    // 1. Normals
    vec3 normal_tex = triplanar_texture(normal_texture, uv_power_normal, uv_triplanar_pos * detail_normal_scale).rgb;
    NORMALMAP = normal_tex;
    NORMALMAP_DEPTH = detail_normal_strength;
    
    // 2. Details (Scratches/Dirt)
    // Sample texture
    vec4 detail_raw = triplanar_texture(detail_texture, uv_power_normal, uv_triplanar_pos * detail_paint_scale);
    // Use Green channel + Contrast
    float detail_val = pow(detail_raw.g, detail_paint_contrast);
    
    // 3. Apply Paint
    // Base Color + (Detail * Strength). Clamped to avoid negative colors.
    ALBEDO = max(paint_color.rgb + (vec3(detail_val) * detail_paint_strength), vec3(0.0));
    if (damage_active > 0.5) {
        float damage_mark = damage_marks(damage_pos.xyz, normalize(damage_normal)) * damage_mark_strength;
        float damage_mark_dither = (bayer - 0.5) * damage_mark_softness;
        damage_mark = step(damage_mark_edge, damage_mark + damage_mark_dither) * step(0.001, damage_mark) * clamp(damage_mark * 1.4 + 0.25, 0.0, 1.0);
        ALBEDO = mix(ALBEDO, damage_mark_color.rgb, damage_mark);
    }
    if (damage_active > 0.5) {
        EMISSION = damage_glow(damage_pos.w);
    }
}

// --- Light Function ---
void light() {
    // Virtual pixel coordinates for DPI-independent dither grid
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);

    // 8x8 Bayer threshold based on scaled screen-space coordinates
    float threshold = bayer8x8(dither_pos);

    // Standard Lambertian intensity
    float NoL = max(0.0, dot(NORMAL, LIGHT));

    // Bi-directional Bayer dithering across quantization steps
    float levels = max(1.0, posterization_levels);
    float step_size = 1.0 / levels;
    float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
    float dithered_NoL = clamp(NoL + dither_offset, 0.0, 1.0);

    // Quantized toon diffuse intensity
    float quantized_NoL = floor(dithered_NoL * levels) / levels;

    // Grazing angle Fresnel rim lighting (active in light)
    float fresnel = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
    float rim = pow(fresnel, rim_exponent) * rim_strength * rim_intensity;

    // Combined diffuse lighting tinted by albedo
    vec3 current_light = ALBEDO * (quantized_NoL + rim * quantized_NoL) * ATTENUATION * LIGHT_COLOR;

    DIFFUSE_LIGHT += current_light;
    SPECULAR_LIGHT += vec3(0.0);
}
