// Harpoon cable ribbon (Tether / TetherRope). Vertex colour red carries the strain, 0 slack .. 1
// full: a loose cable is dull metal, a strained one brightens toward a hot steel sheen. The strain
// is dithered and posterized, so the sheen comes on in bands.
shader_type spatial;
render_mode cull_disabled, unshaded;

uniform vec4 slack_color : hint_color = vec4(0.42, 0.42, 0.46, 1.0);
uniform vec4 strained_color : hint_color = vec4(0.95, 0.9, 0.78, 1.0);
uniform float strain_curve = 1.5; // >1: the sheen comes on late, near full strain

uniform float posterization_levels = 6.0;
uniform float dither_strength = 0.6;

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

void fragment() {
	float strain = dither_posterize(pow(clamp(COLOR.r, 0.0, 1.0), strain_curve), FRAGCOORD.xy);
	ALBEDO = mix(slack_color.rgb, strained_color.rgb, strain);
}
