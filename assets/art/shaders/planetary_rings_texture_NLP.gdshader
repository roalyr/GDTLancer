shader_type spatial;

render_mode
    blend_mix,
    cull_back,
    diffuse_lambert,
    specular_disabled,
    depth_draw_opaque;

uniform vec4 albedo : hint_color = vec4(0.8, 0.75, 0.65, 1.0);

// Noise texture sampled in polar UV space to make radial ring density bands
uniform sampler2D ring_noise : hint_albedo;

// Ring shape: inner hole and outer edge, each with a feathered transition.
// inner_mask_size: 0=no hole, 1=all hole. feathering: width of the blend.
uniform float inner_mask_size : hint_range(0.0, 1.0) = 0.4;
uniform float feathering_inner : hint_range(0.0, 0.2) = 0.02;
uniform float feathering_outer : hint_range(0.0, 0.2) = 0.02;

// Distance at which the texture detail fades out (LOD)
uniform float detail_decay_distance = 1e7;

// Dither and posterization constants
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;
const float light_dither_strength = 0.5;
const float posterization_levels = 5.0;
const float dither_pixel_size = 2.0;

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

// --- Helper Functions ---

// Polar coordinate mapping (radius + angle from center).
// zoom scales radial density; repeat tiles the angular direction.
vec2 polar_coordinates(vec2 uv, vec2 center, float zoom, float repeat) {
    vec2 dir = uv - center;
    float radius = length(dir) * 2.0;
    float angle = atan(dir.y, dir.x) / (3.14159265 * 2.0);
    return mod(vec2(radius * zoom, angle * repeat), 1.0);
}

// Returns 0 inside the circle of given radius, 1 outside (with feathered edge).
float circle_mask(vec2 uv, float radius, float feather) {
    return smoothstep(radius, radius + feather, length(uv - vec2(0.5)));
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

void vertex() {
    float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
    VERTEX *= scale_factor;
}

void fragment() {
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
    float threshold = bayer8x8(dither_pos);

    // --- Ring shape masks ---
    // Outer: 1 inside the disc, 0 outside (inverted circle_mask)
    float mask_outer = 1.0 - circle_mask(UV, 0.5 - feathering_outer, feathering_outer);
    // Inner: 0 inside the hole, 1 in the ring body
    float mask_inner = circle_mask(UV, inner_mask_size, feathering_inner);

    // --- Ring band density from noise in polar UV space ---
    // Polar UV maps radius (radial bands) and angle (uniform across the ring).
    // zoom=0.3 gives ~3 radial repetitions across the ring width.
    vec2 polar_uv = polar_coordinates(UV.xy, vec2(0.5), 0.3, 1.0);
    float ring_noise_val = texture(ring_noise, polar_uv).r;

    // Distance LOD: density fades at very large distances
    float fade = 1.0 - clamp(smoothstep(0.0, detail_decay_distance, length(VERTEX)), 0.0, 1.0);

    // Combined ring presence: shape × noise density × distance fade
    float ring_presence = mask_outer * mask_inner * ring_noise_val * fade;

    // --- Dithered discard — replaces ALPHA ---
    // Pixels where the ring is absent or thin are discarded with Bayer dithering,
    // preserving soft feathered edges without alpha blending.
    if (ring_presence < threshold * dither_threshold + 1e-6) {
        discard;
    }

    // --- Dithered posterization of the color ---
    // ring_noise_val modulates albedo to create bright/dark band variation.
    float levels = max(1.0, posterization_levels);
    float step_size = 1.0 / levels;
    float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;

    vec3 base_color = albedo.rgb * COLOR.rgb * clamp(ring_noise_val, 0.0, 1.0);
    ALBEDO = vec3(
        floor(clamp(base_color.r + dither_offset, 0.0, 1.0) * levels) / levels,
        floor(clamp(base_color.g + dither_offset, 0.0, 1.0) * levels) / levels,
        floor(clamp(base_color.b + dither_offset, 0.0, 1.0) * levels) / levels
    );
}

// --- Light Function ---
void light() {
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
    float threshold = bayer8x8(dither_pos);

    float NoL = max(0.0, dot(NORMAL, LIGHT));

    float levels = max(1.0, posterization_levels);
    float step_size = 1.0 / levels;
    float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
    float dithered_NoL = clamp(NoL + dither_offset, 0.0, 1.0);
    float quantized_NoL = floor(dithered_NoL * levels) / levels;

    DIFFUSE_LIGHT += ALBEDO * quantized_NoL * ATTENUATION * LIGHT_COLOR;
    SPECULAR_LIGHT += vec3(0.0);
}
