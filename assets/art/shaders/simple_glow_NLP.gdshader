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
uniform float dither_strength = 0.5;
uniform float posterization_levels = 24.0;


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
	// Non-linear perspective
	VERTEX = nlp_scale(VERTEX, MODELVIEW_MATRIX);
}

void fragment()
{
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
	float quantized_glow = dither_posterize(glow_intensity, FRAGCOORD.xy);

	ALBEDO = albedo.rgb * quantized_glow;
}
