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
uniform float light_dither_strength = 0.5;
uniform float posterization_levels = 5.0;
const float dither_pixel_size = 2.0;

// NLP
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

const float pi = 3.1415926535;
const vec3 WHITE = vec3(1.0, 1.0, 1.0);

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

// Posterize a single channel
float posterize(float v, float levels) {
    return floor(clamp(v, 0.0, 1.0) * levels) / levels;
}

void vertex() {
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
}

void fragment()
{
	// Virtual pixel coordinates for DPI-independent dither grid
	vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
	float threshold = bayer8x8(dither_pos);

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

	// --- Apply dithering and posterization once on the final composed color ---
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;

	ALBEDO = vec3(
		posterize(col.r + dither_offset, levels),
		posterize(col.g + dither_offset, levels),
		posterize(col.b + dither_offset, levels)
	);
}
