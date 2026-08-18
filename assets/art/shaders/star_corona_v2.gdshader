shader_type spatial;
render_mode
	vertex_lighting,
	blend_add,
	cull_front,
	unshaded,
	specular_disabled,
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 corona_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform float strength_corona : hint_range(0.0, 1e2, 5e-4) = 40;
uniform float exponent_corona = 2;
uniform float exponent_corona_rim = 2;
uniform float corona_floor_power = 5.0;
uniform float corona_floor : hint_range(0.0, 2, 5e-4) = 1.3;

uniform float fade_distance_far = 15000;
uniform float fade_power = 6.0;

// Dither and posterization constants
const float light_dither_strength = 0.5;
const float posterization_levels = 20.0;
const float dither_pixel_size = 2.0;

uniform sampler2D displacement_texture;
uniform float displacement_power : hint_range(-0.4, 0.4, 5e-4) = 0.05;
uniform float displacement_scale_xz : hint_range(0.0, 2.0, 5e-4) = 0.95;
uniform float displacement_scale_y : hint_range(0.0, 2.0, 5e-4) = 0.9;
uniform float displacement_velocity : hint_range(0.0, 2.0, 5e-4) = 0.1;

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

varying float noise_val;

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
	vec2 tex_position_x = VERTEX.yz - TIME * displacement_velocity * 0.1;
	vec2 tex_position_y = VERTEX.xz + TIME * displacement_velocity * 0.1;
	vec2 tex_position_z = VERTEX.xy - TIME * displacement_velocity * 0.1;

	float displacement_x = 2.0 * texture(displacement_texture, tex_position_x).r;
	float displacement_y = 2.0 * texture(displacement_texture, tex_position_y).r;
	float displacement_z = 2.0 * texture(displacement_texture, tex_position_z).r;

	noise_val = pow(displacement_z * displacement_x * displacement_y, displacement_power);
	VERTEX *= noise_val;
	VERTEX.xz *= displacement_scale_xz;
	VERTEX.y *= displacement_scale_y;

	// Non-linear perspective
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float scale_factor = pow(clamp((scale_end_mul * scale_start - distance_vert) / (scale_end_mul * scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
}

void fragment()
{
	// Virtual pixel coordinates for DPI-independent dither grid
	vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
	float threshold = bayer8x8(dither_pos);

	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-9, 0.99999);
	float corona = pow(dt, exp(exponent_corona)) * pow(1.1, strength_corona);

	// Noise mask: corona_floor controls how much of the noise suppresses the rim
	float noise_mask = clamp(corona_floor - pow(noise_val, corona_floor_power), 0.0, 1.0);
	float corona_val = pow(corona, exponent_corona_rim) * noise_mask;

	// Fade by vertex distance (smoothstep in → bright when close, fades out far away)
	float dist = length(VERTEX);
	float fade = pow(clamp(smoothstep(0.0, fade_distance_far, dist), 1e-6, 1.0), fade_power);

	// Clamp corona to [0,1] BEFORE fade and dithering so the dither offset
	// has full headroom across the whole range (avoids clipping bright regions to 1.0
	// with no dither benefit there, and preserves gradient detail in mid-tones).
	float final_val = clamp(corona_val, 0.0, 1.0) * fade;

	// Bi-directional Bayer dithering and posterization on the fully composed value
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
	float dithered_val = clamp(final_val + dither_offset, 0.0, 1.0);
	float quantized_val = floor(dithered_val * levels) / levels;

	ALBEDO = corona_color.rgb * quantized_val;
}
