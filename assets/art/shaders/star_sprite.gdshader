shader_type spatial;
render_mode
    blend_add,
    cull_back,
    unshaded,
    depth_draw_opaque;

uniform vec4 albedo : hint_color = vec4(1.0);

uniform float scale_near : hint_range(0.0, 10.0) = 1.0;
uniform float scale_peak : hint_range(0.0, 10.0) = 1.0;
uniform float scale_far : hint_range(0.0, 10.0) = 0.2;

uniform float peak_distance = 50000.0;
uniform float fade_ratio : hint_range(1.0, 20.0) = 10.0;
uniform float distance_power : hint_range(0.1, 8.0) = 0.4;

uniform float fade_distance_near : hint_range(0.0, 1e6) = 0.0;
uniform float fade_distance_far : hint_range(0.0, 2e6) = 2e6;
uniform float fade_power = 5;

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float exponent : hint_range(0.0, 50.0, 0.1) = 3.0;

// Dither and posterization constants
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;
const float light_dither_strength = 0.5;
const float posterization_levels = 24.0;
const float dither_pixel_size = 2.0;

// --- Helper Functions ---

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

void vertex() {
    float center_distance = max(-NODE_POSITION_VIEW.z, 0.0001);
    float fade_distance = peak_distance * fade_ratio;

    float sprite_scale;
    if (center_distance < peak_distance) {
        float t = pow(clamp(center_distance / peak_distance, 0.0, 1.0), distance_power);
        sprite_scale = mix(scale_near, scale_peak, t);
    } else if (center_distance < fade_distance) {
        float t = pow(
            clamp(
                (center_distance - peak_distance) / max(fade_distance - peak_distance, 0.0001),
                0.0,
                1.0
            ),
            distance_power
        );
        sprite_scale = mix(scale_peak, scale_far, t);
    } else {
        sprite_scale = scale_far;
    }

    MODELVIEW_MATRIX = INV_CAMERA_MATRIX * mat4(
        CAMERA_MATRIX[0],
        CAMERA_MATRIX[1],
        CAMERA_MATRIX[2],
        vec4(NODE_POSITION_WORLD, 1.0)
    );

    if (PROJECTION_MATRIX[3][3] != 0.0) {
        float sc = abs(1.0 / PROJECTION_MATRIX[1][1]) * sprite_scale;
        MODELVIEW_MATRIX[0] *= sc;
        MODELVIEW_MATRIX[1] *= sc;
        MODELVIEW_MATRIX[2] *= sc;
    } else {
        float sc = center_distance * sprite_scale;
        MODELVIEW_MATRIX[0] *= sc;
        MODELVIEW_MATRIX[1] *= sc;
        MODELVIEW_MATRIX[2] *= sc;
    }
}

void fragment() {
    // Virtual pixel coordinates for DPI-independent dither grid
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
    float threshold = bayer8x8(dither_pos);

	// Fade near and far.
	float dist = length(VERTEX);
	float fade_out = clamp(smoothstep(fade_distance_far, 0.0, dist), 1e-6, 1.0); // fades out
	float fade_in = clamp(smoothstep(0.0, fade_distance_near, dist), 1e-6, 1.0); // fades in
	float fade = pow(fade_in*fade_out, fade_power);

	// sprite_val is already in [0,1] (COLOR.r^exponent * intensity).
	// Bake fade in before posterizing so bands stay crisp through the fade zone.
	float sprite_val = clamp(pow(COLOR.r, exponent) * intensity * fade, 0.0, 1.0);

	// Bi-directional Bayer dithering and posterization on the fully composed value
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
	float dithered_val = clamp(sprite_val + dither_offset, 0.0, 1.0);
	float quantized_val = floor(dithered_val * levels) / levels;

    ALBEDO = albedo.rgb * quantized_val;
}