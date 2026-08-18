shader_type spatial;

render_mode
    // Additive blend — ring haze is an atmospheric glow effect.
    // cull_front renders the inner face, giving the edge-on haze band look.
    blend_add,
    cull_front,
    unshaded,
    specular_disabled,
    ambient_light_disabled,
    depth_draw_opaque;

uniform vec4 albedo : hint_color = vec4(0.8, 0.85, 1.0, 1.0);

// rim_exponent: how tight the edge-on band is. Low = wide haze, high = sharp thin band.
uniform float rim_strength : hint_range(0.0, 5.0, 0.01) = 1.5;
uniform float rim_exponent : hint_range(0.0, 50.0, 0.1) = 1.5;

// Distance at which the ring haze starts fading out (detail LOD)
uniform float detail_decay_distance = 1e7;

// Dither and posterization constants
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;
const float light_dither_strength = 0.5;
const float posterization_levels = 24.0;
const float dither_pixel_size = 2.0;

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

// --- Helper Functions ---

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

void vertex() {
    float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
    VERTEX *= scale_factor;
}

void fragment() {
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
    float threshold = bayer8x8(dither_pos);

    // Fresnel: 1.0 = face-on (transparent/empty), 0.0 = edge-on (dense haze).
    // We use (1 - dt) so the ring is visible edge-on and invisible face-on.
    float dt = clamp(dot(NORMAL, VIEW), 1e-6, 1.0);
    float rim = clamp(pow(dt, rim_exponent) * rim_strength, 0.0, 1.0);

    // Distance fade: haze disappears at very large distances
    float fade = 1.0 - clamp(smoothstep(0.0, detail_decay_distance, length(VERTEX)), 0.0, 1.0);

    // Compose final intensity: rim drives the haze density, fade LODs it out
    float final_val = clamp(rim * fade, 0.0, 1.0);

    // Dithered posterization (same pattern as glow/corona shaders)
    float levels = max(1.0, posterization_levels);
    float step_size = 1.0 / levels;
    float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
    float dithered_val = clamp(final_val + dither_offset, 0.0, 1.0);
    float quantized_val = floor(dithered_val * levels) / levels;

    ALBEDO = albedo.rgb * COLOR.rgb * quantized_val;
}
