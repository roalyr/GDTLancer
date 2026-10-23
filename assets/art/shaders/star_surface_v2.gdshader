shader_type spatial;
render_mode
	vertex_lighting,
	blend_mix,
	cull_back,
	unshaded,
	specular_disabled,
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 rim_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 overlay_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 surface_color : hint_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform vec4 fade_color : hint_color = vec4(1.0, 1.0, 0.0, 1.0);

uniform float major_phase : hint_range(0, 3.14) = 0.95;

uniform float major_detail_intensity = 1.0;
uniform float major_detail_level  = 0.5;
uniform float detail_decay_distance = 50000;
uniform float detail_decay_power : hint_range(0.0, 5.0, 5e-4) = 2.0;

uniform sampler2D major_detail_noise : hint_albedo;

uniform float major_detail_scale : hint_range(1.0, 10.0, 1.0) = 1;

uniform float major_detail_flow = 0.01;

uniform float rim_strength = 1.0;
uniform float rim_exponent = 0.03;
uniform float rim_intensity = 10;

// Dither and posterization constants
uniform float dither_strength = 0.5;
uniform float posterization_levels = 5.0;


const float pi = 3.1415926535;
const vec3 WHITE = vec3(1.0, 1.0, 1.0);

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
	VERTEX = nlp_scale(VERTEX, MODELVIEW_MATRIX);
}

void fragment()
{
	// --- Full-precision intermediate values ---
	vec2 p = texture(major_detail_noise, -UV * 2.0 * major_detail_scale).xy - TIME * major_detail_flow;
	float detail = abs(sin(pow(texture(major_detail_noise, p).r, major_detail_level) * pi + major_phase));
	float rim = clamp(pow(abs(dot(NORMAL, VIEW)), rim_exponent) * rim_strength, 1e-6, 1.0);
	float distance_factor = clamp(pow(length(VERTEX) / detail_decay_distance, detail_decay_power), 0.0, 1.0);

	// --- Compose final color at full float precision ---
	vec3 col = detail * major_detail_intensity * (1.0 - distance_factor) * WHITE;
	col += overlay_color.rgb;
	col *= surface_color.rgb;
	col += fade_color.rgb * distance_factor;
	col += (1.0 - rim) * rim_color.rgb * rim_intensity * (1.0 - distance_factor);

	// --- Dithered and posterized once, on the final composed color ---
	ALBEDO = dither_posterize3(col, FRAGCOORD.xy);
}
