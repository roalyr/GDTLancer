// Solid: opaque, lit surfaces (ships, rocks, stations, planets). Toon lighting: the light is
// dithered and posterized in light(), plus a Fresnel rim.
// - Colour: `albedo` times the vertex colour (white on meshes without one), plus emission.
// - Optional triplanar detail (scratches, dirt: detail_texture's green channel lightens or darkens
//   by detail_paint_strength) and normal map (detail_normal_strength). Each is sampled only while
//   its strength is not 0, so untextured materials skip the texture reads.
// - Far away (fade_start .. fade_start * fade_end_mul) it dithers out; farther still, NLP shrinks it.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 albedo : hint_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 emission : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 500.0, 0.1) = 1.0;

// Triplanar detail, in the model's own space.
uniform sampler2D detail_texture : hint_white;  // Green channel: scratches, dirt
uniform sampler2D normal_texture : hint_normal;
uniform float detail_paint_scale = 1.0;
uniform float detail_paint_strength : hint_range(-1.0, 1.0) = 0.0;  // 0: off; < 0 darkens, > 0 lightens
uniform float detail_paint_contrast : hint_range(0.1, 10.0) = 1.0;
uniform float detail_normal_scale = 1.0;
uniform float detail_normal_strength : hint_range(-5.0, 5.0) = 0.0;  // 0: off
uniform float uv_triplanar_sharpness : hint_range(0.0, 100.0) = 10.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

// Rim light (light()).
uniform float rim_strength = 1.0;
uniform float rim_exponent = 3.0;
uniform float rim_intensity = 0.3;

// Distance fade: dithered out between fade_start and fade_start * fade_end_mul.
uniform float fade_start = 300000.0;
uniform float fade_end_mul = 5.0;
uniform float fade_power = 2.0;

uniform float posterization_levels = 6.0;  // Light bands
uniform float dither_strength = 0.9;

varying vec3 uv_triplanar_pos;
varying vec3 uv_power_normal;

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

vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_pos) {
	vec4 samp = vec4(0.0);
	samp += texture(p_sampler, p_pos.xy) * p_weights.z;
	samp += texture(p_sampler, p_pos.xz) * p_weights.y;
	samp += texture(p_sampler, p_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
	return samp;
}

void vertex() {
	// Triplanar mapping in model space, before NLP, so the detail stays put on the surface.
	TANGENT = normalize(vec3(0.0, 0.0, -1.0) * abs(NORMAL.x) + vec3(1.0, 0.0, 0.0) * abs(NORMAL.y) + vec3(1.0, 0.0, 0.0) * abs(NORMAL.z));
	BINORMAL = normalize(vec3(0.0, 1.0, 0.0) * abs(NORMAL.x) + vec3(0.0, 0.0, -1.0) * abs(NORMAL.y) + vec3(0.0, 1.0, 0.0) * abs(NORMAL.z));
	uv_power_normal = pow(abs(NORMAL), vec3(uv_triplanar_sharpness));
	uv_power_normal /= dot(uv_power_normal, vec3(1.0));
	uv_triplanar_pos = (VERTEX * uv_scale + uv_offset) * vec3(1.0, -1.0, 1.0);

	VERTEX = nlp_scale(VERTEX, MODELVIEW_MATRIX);
}

void fragment() {
	float distance_vert = length(VERTEX);
	float fade_range = fade_end_mul * fade_start - fade_start;
	if (fade_range > 0.0 && distance_vert > fade_start) {
		float fade_factor = pow(clamp((fade_end_mul * fade_start - distance_vert) / fade_range, 0.0, 1.0), fade_power);
		if (fade_factor < bayer_at(FRAGCOORD.xy) + 1e-6) {
			discard;
		}
	}

	vec3 color = albedo.rgb * COLOR.rgb;
	if (detail_paint_strength != 0.0) {
		float detail = pow(triplanar_texture(detail_texture, uv_power_normal, uv_triplanar_pos * detail_paint_scale).g, detail_paint_contrast);
		color = max(color + vec3(detail * detail_paint_strength), vec3(0.0));
	}
	ALBEDO = color;
	if (detail_normal_strength != 0.0) {
		NORMALMAP = triplanar_texture(normal_texture, uv_power_normal, uv_triplanar_pos * detail_normal_scale).rgb;
		NORMALMAP_DEPTH = detail_normal_strength;
	}
	EMISSION = emission.rgb * COLOR.rgb * emission_strength;
}

void light() {
	// Lambert, dithered and posterized into toon bands; the rim brightens lit edges.
	float lit = dither_posterize(max(0.0, dot(NORMAL, LIGHT)), FRAGCOORD.xy);
	float fresnel = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	float rim = pow(fresnel, rim_exponent) * rim_strength * rim_intensity;
	DIFFUSE_LIGHT += ALBEDO * (lit + rim * lit) * ATTENUATION * LIGHT_COLOR;
}
