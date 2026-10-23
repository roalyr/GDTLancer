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
uniform float dither_strength = 0.5;
uniform float posterization_levels = 20.0;

uniform sampler2D displacement_texture;
uniform float displacement_power : hint_range(-0.4, 0.4, 5e-4) = 0.05;
uniform float displacement_scale_xz : hint_range(0.0, 2.0, 5e-4) = 0.95;
uniform float displacement_scale_y : hint_range(0.0, 2.0, 5e-4) = 0.9;
uniform float displacement_velocity : hint_range(0.0, 2.0, 5e-4) = 0.1;


varying float noise_val;

// --- Helper Functions ---

// @common dither
// Bayer dithering and posterization, the look every shader shares. The shader declares
// `uniform float posterization_levels` (bands over 0..1) and `uniform float dither_strength`
// (0: hard bands, 1: dithered a whole band either way).
const float DITHER_PIXEL_SIZE = 2.0;  // Screen pixels per dither cell

float bayer2x2(vec2 p) {
	return p.x * 2.0 + p.y * (3.0 - 4.0 * p.x);
}

// 8x8 Bayer threshold (0..1) without arrays (GLES2).
float bayer8x8(vec2 screen_pos) {
	vec2 p = mod(floor(screen_pos), 8.0);
	vec2 p0 = mod(p, 2.0);
	vec2 p1 = mod(floor(p / 2.0), 2.0);
	vec2 p2 = floor(p / 4.0);
	float val = 16.0 * bayer2x2(p0) + 4.0 * bayer2x2(p1) + bayer2x2(p2);
	return val / 64.0;
}

// The dither threshold (0..1) at a fragment (FRAGCOORD.xy).
float bayer_at(vec2 fragcoord) {
	return bayer8x8(fragcoord / DITHER_PIXEL_SIZE);
}

// `value` (0..1) dithered both ways, then cut to posterization_levels bands.
float dither_posterize(float value, vec2 fragcoord) {
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dithered = clamp(value + (bayer_at(fragcoord) - 0.5) * step_size * dither_strength, 0.0, 1.0);
	return floor(dithered * levels) / levels;
}

// dither_posterize() per channel, one threshold for all three.
vec3 dither_posterize3(vec3 value, vec2 fragcoord) {
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	vec3 dithered = clamp(value + vec3((bayer_at(fragcoord) - 0.5) * step_size * dither_strength), 0.0, 1.0);
	return floor(dithered * levels) / levels;
}
// @end

// @common nlp
// Non-linear perspective: from scale_start out to scale_start * scale_end_mul from the camera, a
// mesh shrinks about its origin to scale_min of its size (scale_power shapes the curve), so huge,
// far bodies stay inside the camera's range. Call in vertex(): VERTEX = nlp_scale(VERTEX, MODELVIEW_MATRIX).
uniform float scale_start = 100000.0;
uniform float scale_end_mul = 100.0;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

vec3 nlp_scale(vec3 vertex, mat4 modelview) {
	float distance_vert = -(modelview * vec4(vertex, 1.0)).z;
	float scale_factor = pow(clamp((scale_end_mul * scale_start - distance_vert) / (scale_end_mul * scale_start - scale_start), scale_min, 1.0), scale_power);
	return vertex * scale_factor;
}
// @end

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
	VERTEX = nlp_scale(VERTEX, MODELVIEW_MATRIX);
}

void fragment()
{
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
	float quantized_val = dither_posterize(final_val, FRAGCOORD.xy);

	ALBEDO = corona_color.rgb * quantized_val;
}
