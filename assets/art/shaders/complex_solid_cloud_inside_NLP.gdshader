shader_type spatial;

render_mode
	vertex_lighting,
	blend_mix,
	cull_front,
	unshaded,
	diffuse_lambert,
	specular_disabled,
	ambient_light_disabled,
	depth_draw_opaque;

uniform float vertex_mask_power = 1.0;
uniform float vertex_mask_overlay = 0.0;
uniform float albedo_strength = 1.0;
uniform float lum_weight_r = 1.0;
uniform float lum_weight_g = 1.0;
uniform float lum_weight_b = 1.0;

uniform float color_power_r = 1.0;
uniform float color_power_g = 1.0;
uniform float color_power_b = 1.0;
uniform float color_multiplier_r = 1.0;
uniform float color_multiplier_g = 1.0;
uniform float color_multiplier_b = 1.0;

uniform vec4 albedo : hint_color;
uniform vec4 albedo_near : hint_color;
uniform vec4 albedo_ambient : hint_color;
uniform vec4 albedo_far : hint_color;

uniform float fade_distance = 1e5;
uniform float fade_distance_far = 3e5;
uniform float fade_power = 2.0;

uniform float rim_exponent = 0.5;

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

const float pi = 3.1415926535;

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

	float luminosity = dot(COLOR.rgb, vec3(lum_weight_r, lum_weight_g, lum_weight_b));
	luminosity = max(luminosity, 0.0);

	// Calculated luminosity value
	float vertex_mask = vertex_mask_overlay + pow(luminosity, vertex_mask_power);
	if (vertex_mask < 0.01) {
		discard;
	}

	// Bi-directional Bayer dithering across quantization steps
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;

	float q_mask = floor(clamp(vertex_mask + dither_offset, 0.0, 1.0) * levels) / levels;
	
	ALBEDO = albedo_strength * albedo.rgb * COLOR.rgb;
	
	// Apply vertex mask
	ALBEDO *= q_mask;
	
	// color tweak.
	ALBEDO = vec3(
		pow(ALBEDO.r, color_power_r)*color_multiplier_r,
		pow(ALBEDO.g, color_power_g)*color_multiplier_g,
		pow(ALBEDO.b, color_power_b)*color_multiplier_b
	);

	// Overlay dark parts
	ALBEDO += (1.0 - clamp(q_mask, 0.0, 1.0)) * albedo_ambient.rgb;
	
	// Replace near parts with ambient color to hide polygons.
	float dist = length(VERTEX);
	float fade = pow(clamp(smoothstep(0.0, fade_distance, dist), 1e-6, 1.0), fade_power); // fades in
	float fade_far = pow(clamp(smoothstep(0.0, fade_distance_far, dist), 1e-6, 1.0), fade_power); // fades out
	float q_fade = floor(clamp(fade + dither_offset, 0.0, 1.0) * levels) / levels;
	float q_fade_far = floor(clamp(fade_far + dither_offset, 0.0, 1.0) * levels) / levels;

	vec3 current = ALBEDO;
	ALBEDO = (1.0-q_fade) * (albedo_near.rgb * q_mask) // Near fade in color
		+ (1.0-q_fade) * (albedo_ambient.rgb * (1.0 - q_mask)) // Adjusted by mask
		+ q_fade * (1.0-q_fade_far) * current // Mesh color between fade in and fade out
		+ (q_fade_far) * (albedo_ambient.rgb) // Adjusted by mask
		;
}