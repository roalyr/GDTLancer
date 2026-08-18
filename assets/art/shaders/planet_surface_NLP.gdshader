shader_type spatial;

render_mode
    blend_mix,
    cull_back,
    diffuse_lambert,
    specular_phong,
    depth_draw_opaque;

// =============================================================================
// SURFACE BASE COLORS
// Three Fresnel-modulated color layers, same principle as solid_dither:
//   albedo      = base rock/ground fill (flat to slight edge)
//   albedo_ice  = ice/water specular layer color (mid-edge)
//   albedo_gloss= tight gloss highlight on ice/water (tight edge)
// =============================================================================
uniform vec4 albedo : hint_color = vec4(0.25, 0.2, 0.18, 1.0);
uniform vec4 albedo_overlay : hint_color = vec4(0.1, 0.08, 0.06, 1.0);
uniform vec4 albedo_ice : hint_color = vec4(0.7, 0.85, 1.0, 1.0);
uniform vec4 albedo_gloss : hint_color = vec4(0.95, 0.98, 1.0, 1.0);

// =============================================================================
// FRESNEL EXPONENTS
// albedo_exponent=0 → flat fill; higher → more edge-concentrated
// =============================================================================
uniform float albedo_exponent : hint_range(0.0, 50.0, 0.1) = 0.0;
uniform float ice_exponent : hint_range(0.0, 100.0, 0.1) = 3.0;
uniform float gloss_exponent : hint_range(0.0, 500.0, 0.1) = 20.0;
uniform float roughness_exponent : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform float roughness_sharpness : hint_range(0.0, 100.0, 0.1) = 8.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;

// =============================================================================
// ATMOSPHERE / HAZE RIM
// Adds haze glow at the planetary limb in both lit and shadowed zones.
// haze_color     = atmosphere edge color
// haze_strength  = how much haze is added at the rim
// haze_exponent  = how tight/narrow the haze band is
// haze_in_shadow = fraction of haze visible in the unlit zone (flat, 0-1)
// =============================================================================
uniform vec4 haze_color : hint_color = vec4(0.4, 0.65, 1.0, 1.0);
uniform float haze_strength : hint_range(0.0, 5.0, 0.01) = 0.5;
uniform float haze_exponent : hint_range(0.0, 20.0, 0.1) = 3.0;
uniform float haze_in_shadow : hint_range(0.0, 1.0) = 0.15;

// =============================================================================
// LAVA / EMISSION
// Lava mask = animated noise minus terrain mask (reveals cracks between plates).
// lava_color         = emission color of lava
// lava_intensity     = emission brightness multiplier
// lava_contrast      = how sharply the terrain mask suppresses lava
// lava_noise_blend   = exponent that sharpens the terrain masking
// lava_flow          = animation speed of lava noise
// lava_decay_distance= lava fades at distances above this (detail LOD)
// =============================================================================
uniform vec4 lava_color : hint_color = vec4(1.0, 0.3, 0.05, 1.0);
uniform float lava_intensity : hint_range(0.0, 10.0, 0.01) = 1.0;
uniform float lava_contrast : hint_range(0.0, 10.0, 0.01) = 3.0;
uniform float lava_noise_blend : hint_range(0.0, 2.0, 0.01) = 0.7;
uniform float lava_flow : hint_range(0.0, 0.1, 0.0001) = 0.005;
uniform float lava_phase : hint_range(0.0, 3.14) = 1.0;
uniform float lava_mask_phase : hint_range(0.0, 3.14) = 1.4;
uniform float lava_decay_distance = 1e6;

// =============================================================================
// ICE / WATER MASK
// Derived from terrain noise at a different phase; controls how much the
// ice/gloss Fresnel layers contribute. Separate phase lets you dial in
// whether ice sits on high or low terrain features.
// =============================================================================
uniform float ice_mask_phase : hint_range(0.0, 3.14) = 2.0;
uniform float ice_amount : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float ice_noise_blend : hint_range(0.0, 2.0, 0.01) = 0.3;
uniform float ice_intensity : hint_range(0.0, 2.0, 0.01) = 1.0;

// =============================================================================
// TERRAIN NOISE (large scale — two passes, same texture, different scales)
// phase controls which part of the sinusoidal range is "land" vs "sea/cracks"
// =============================================================================
uniform sampler2D noise_terrain : hint_albedo;
uniform float terrain_phase : hint_range(0.0, 3.14) = 1.4;
uniform float terrain_scale : hint_range(1.0, 10.0, 0.5) = 1.0;
uniform float terrain_detail_scale : hint_range(1.0, 20.0, 0.5) = 5.0;
uniform float terrain_detail_phase : hint_range(0.0, 3.14) = 1.0;
uniform float terrain_detail_intensity : hint_range(0.0, 2.0, 0.01) = 0.5;

// =============================================================================
// LAVA / DETAIL NOISE (small scale — animated, used for lava crack detail)
// Reuses the same noise texture at a different scale/phase.
// =============================================================================
uniform float lava_detail_scale : hint_range(1.0, 100.0, 0.5) = 20.0;

// =============================================================================
// LOD DISCARD FADE
// =============================================================================
uniform float fade_start = 300000.0;
uniform float fade_end_mul = 5.0;
uniform float fade_power = 2.0;
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;

// =============================================================================
// DITHER / POSTERIZATION CONSTANTS
// =============================================================================
const float light_dither_strength = 0.5;
const float posterization_levels = 5.0;
const float dither_pixel_size = 2.0;

// =============================================================================
// TRIPLANAR / NLP
// =============================================================================
uniform float uv_triplanar_sharpness : hint_range(0.0, 100.0) = 10.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

varying vec3 uv_triplanar_pos;
varying vec3 uv_power_normal;

const float pi = 3.1415926535;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_triplanar_pos) {
    vec4 samp = vec4(0.0);
    samp += texture(p_sampler, p_triplanar_pos.xy) * p_weights.z;
    samp += texture(p_sampler, p_triplanar_pos.xz) * p_weights.y;
    samp += texture(p_sampler, p_triplanar_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
    return samp;
}

float bayer2x2(vec2 p) {
    return p.x * 2.0 + p.y * (3.0 - 4.0 * p.x);
}

float bayer8x8(vec2 screen_pos) {
    vec2 p = mod(floor(screen_pos), 8.0);
    vec2 p0 = mod(p, 2.0);
    vec2 p1 = mod(floor(p / 2.0), 2.0);
    vec2 p2 = floor(p / 4.0);
    float val = 16.0 * bayer2x2(p0) + 4.0 * bayer2x2(p1) + bayer2x2(p2);
    return val / 64.0;
}

// Star-surface sinusoidal noise sampling:
// Uses one noise texture read to warp UV, then a second read through the warped coords.
// Result passed through sin(pow(v, level)*pi + phase) → maps the [0,1] noise range
// into a shaped wave, creating terrain-like banding without hand-drawn masks.
float terrain_noise_sample(sampler2D tex, vec3 weights, vec3 pos, float scale, float phase) {
    vec3 warp_pos = pos * scale;
    vec2 warp = triplanar_texture(tex, weights, warp_pos).xy;
    // warp offsets the second sample like the star surface does
    vec3 sampled_pos = pos * scale + vec3(warp * 2.0 - 1.0, 0.0) * 0.5;
    float raw = triplanar_texture(tex, weights, sampled_pos).r;
    return sin(raw * pi + phase);
}

// =============================================================================
// VERTEX
// =============================================================================
void vertex() {
    // Non-linear perspective
    float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
    VERTEX *= scale_factor;

    // TBN for triplanar
    TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
    TANGENT = normalize(TANGENT);
    BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x);
    BINORMAL += vec3(0.0, 0.0, -1.0) * abs(NORMAL.y);
    BINORMAL += vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
    BINORMAL = normalize(BINORMAL);

    uv_power_normal = pow(abs(NORMAL), vec3(uv_triplanar_sharpness));
    uv_power_normal /= dot(uv_power_normal, vec3(1.0));

    uv_triplanar_pos = VERTEX * uv_scale + uv_offset;
    uv_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

// =============================================================================
// FRAGMENT
// =============================================================================
void fragment() {
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);

    // --- LOD discard dithering ---
    float distance_vert = length(VERTEX);
    float fade_range = fade_end_mul * fade_start - fade_start;
    if (fade_range > 0.0 && distance_vert > fade_start) {
        float fade_factor = pow(clamp((fade_end_mul * fade_start - distance_vert) / fade_range, 0.0, 1.0), fade_power);
        float bayer_val = bayer8x8(dither_pos);
        if (fade_factor < bayer_val * dither_threshold + 1e-6) {
            discard;
        }
    }

    // -------------------------------------------------------------------------
    // TERRAIN MASK (large scale, static)
    // Two passes: major terrain (big landmasses) and detail terrain (smaller
    // features that modulate the base color and provide the lava crack mask).
    // -------------------------------------------------------------------------
    float terrain_major = terrain_noise_sample(noise_terrain, uv_power_normal, uv_triplanar_pos, terrain_scale, terrain_phase);
    float terrain_detail = terrain_noise_sample(noise_terrain, uv_power_normal, uv_triplanar_pos, terrain_detail_scale, terrain_detail_phase);
    // Clamp terrain to positive range (negative = "below surface" = cracks/seas)
    float terrain = clamp(terrain_major, 0.0, 1.0);
    float terrain_combined = clamp(terrain * (terrain_detail * terrain_detail_intensity + (1.0 - terrain_detail_intensity)), 0.0, 1.0);

    // -------------------------------------------------------------------------
    // ICE / WATER MASK
    // Same terrain noise at a different phase — maps a different band of the
    // terrain distribution as "ice/water" without any second texture.
    // ice_noise_blend sharpens it into a threshold-like mask.
    // -------------------------------------------------------------------------
    float ice_raw = terrain_noise_sample(noise_terrain, uv_power_normal, uv_triplanar_pos, terrain_scale, ice_mask_phase);
    float ice_mask = clamp(pow(max(ice_raw * ice_amount, 0.0), max(ice_noise_blend, 0.001)), 0.0, 1.0) * ice_intensity;

    // -------------------------------------------------------------------------
    // LAVA MASK (animated small-scale noise minus terrain mask)
    // Lava appears in the "cracks" between terrain plates — where terrain_major
    // is low (negative/zero), the lava mask suppression is weakest.
    // lava_mask_phase shifts the terrain into a mask that suppresses lava
    // on high terrain (rock), revealing it only in low terrain (cracks).
    // -------------------------------------------------------------------------
    float lava_decay = clamp(1.0 - distance_vert / lava_decay_distance, 0.0, 1.0);
    vec3 lava_pos = uv_triplanar_pos * lava_detail_scale;
    // Animated warp offset (like star surface flow)
    vec2 lava_warp = triplanar_texture(noise_terrain, uv_power_normal, lava_pos).xy - TIME * lava_flow;
    float lava_raw = triplanar_texture(noise_terrain, uv_power_normal, vec3(lava_warp, 0.0) * lava_detail_scale).r;
    float lava_detail = sin(lava_raw * pi + lava_phase);

    // Terrain suppression mask at a different phase (same as old lava shader)
    float terrain_lava_mask = sin(triplanar_texture(noise_terrain, uv_power_normal, uv_triplanar_pos * terrain_scale).r * pi + lava_mask_phase);
    float lava_mask = clamp(
        lava_detail - clamp(pow(max(terrain_lava_mask, 0.0), lava_noise_blend), 1e-6, 1.0) * lava_contrast,
        0.0, 1.0) * lava_intensity * lava_decay;

    // -------------------------------------------------------------------------
    // FRESNEL
    // dt = 1.0 face-on, 0.0 grazing edge
    // -------------------------------------------------------------------------
    float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float albedo_rim  = clamp(pow(dt, max(albedo_exponent, 0.001)), 0.0, 1.0);
    float ice_rim     = clamp(pow(dt, max(ice_exponent,    0.001)), 0.0, 1.0);
    float gloss_rim   = clamp(pow(dt, max(gloss_exponent,  0.001)), 0.0, 1.0);
    float roughness_rim = clamp(pow(dt, max(roughness_exponent, 0.001)), 0.0, 1.0);
    // Atmosphere haze — at the grazing edge (1-dt)
    float haze_rim    = pow(1.0 - dt, max(haze_exponent, 0.001));

    // -------------------------------------------------------------------------
    // ALBEDO COMPOSITION
    // Layer 1: base terrain surface (Fresnel-shaped, modulated by terrain noise)
    // Layer 2: ice/water (Fresnel-shaped, gated by ice_mask)
    // Layer 3: tight gloss on ice (very edge-concentrated, gated by ice_mask)
    // -------------------------------------------------------------------------
    ALBEDO = albedo.rgb         * albedo_rim * terrain_combined
           + albedo_overlay.rgb * (1.0 - terrain_combined)    // dark overlay in cracks/seas
           + albedo_ice.rgb     * ice_rim    * ice_mask
           + albedo_gloss.rgb   * gloss_rim  * ice_mask;
    ALBEDO *= COLOR.rgb;

    // Atmosphere haze added flat (visible even without lights, like emission)
    // haze_in_shadow provides a constant ambient fraction at the rim.
    ALBEDO += haze_color.rgb * (haze_rim * haze_strength + haze_in_shadow * haze_rim);

    // -------------------------------------------------------------------------
    // ROUGHNESS
    // High roughness base, reduced where ice exists and at grazing edges.
    // -------------------------------------------------------------------------
    ROUGHNESS = roughness * (1.0 - ice_mask * pow(1.0 - roughness_rim, roughness_sharpness));

    // -------------------------------------------------------------------------
    // EMISSION (lava)
    // -------------------------------------------------------------------------
    EMISSION = lava_color.rgb * lava_mask;
}

// =============================================================================
// LIGHT — dithered posterized Lambert + haze rim
// =============================================================================
void light() {
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
    float threshold = bayer8x8(dither_pos);

    float NoL = max(0.0, dot(NORMAL, LIGHT));

    // Dithered + posterized Lambert
    float levels = max(1.0, posterization_levels);
    float step_size = 1.0 / levels;
    float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
    float dithered_NoL = clamp(NoL + dither_offset, 0.0, 1.0);
    float quantized_NoL = floor(dithered_NoL * levels) / levels;

    // Atmosphere haze rim is brighter on the lit limb
    float dt = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
    float haze_rim = pow(1.0 - dt, max(haze_exponent, 0.001));
    vec3 lit_haze = haze_color.rgb * haze_rim * haze_strength * quantized_NoL;

    DIFFUSE_LIGHT += (ALBEDO * quantized_NoL + lit_haze) * ATTENUATION * LIGHT_COLOR;
    SPECULAR_LIGHT += vec3(0.0);
}
