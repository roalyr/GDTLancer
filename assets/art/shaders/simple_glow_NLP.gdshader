shader_type spatial;
render_mode
	vertex_lighting,
	blend_add,
	cull_front,
	unshaded,
	specular_disabled,
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;

uniform float fade_distance_near = 100;
uniform float fade_distance_far = 1000;
uniform float fade_power = 1.0;

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
	// Non-linear perspective
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
}

void fragment()
{
	// Virtual pixel coordinates for DPI-independent dither grid
	vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
	float threshold = bayer8x8(dither_pos);

	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);

	// Fade near and far.
	float dist = length(VERTEX);
	float fade_out = clamp(smoothstep(fade_distance_far, 0.0, dist), 1e-6, 1.0); // fades out
	float fade_in = clamp(smoothstep(0.0, fade_distance_near, dist), 1e-6, 1.0); // fades in
	float fade = pow(fade_in*fade_out, fade_power);

	// Clamp glow to [0,1] before dithering — rim_strength/rim_outer_strength can push
	// the raw value above 1.0, causing clipping with no dither benefit in bright regions.
	// Bake fade in before posterizing so bands stay crisp through the fade zone.
	float glow_intensity = clamp(rim_floor * rim_outer + pow(rim, rim_power), 0.0, 1.0) * fade;

	// Bi-directional Bayer dithering and posterization on the fully composed value
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
	float dithered_glow = clamp(glow_intensity + dither_offset, 0.0, 1.0);
	float quantized_glow = floor(dithered_glow * levels) / levels;

	ALBEDO = albedo.rgb * quantized_glow;
}
