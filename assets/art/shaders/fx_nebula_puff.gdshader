// A nebula cloud's puff (NebulaCloud): a soft, unlit, additive glow on a camera-facing quad, lumpy
// with value noise, fading out as the camera comes close (so flying through it never blanks the
// screen) and with distance.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : hint_color = vec4(0.35, 0.5, 0.9, 1.0);
uniform float strength = 0.25;
uniform float seed = 0.0;
uniform float near_fade = 1500.0; // m: gone this close to the camera
uniform float near_full = 6000.0; // m: full from here out
uniform float far_fade = 120000.0; // m: gone by here

// Dither and posterization (the dither block).
uniform float posterization_levels = 24.0;
uniform float dither_strength = 0.5;

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

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	MODELVIEW_MATRIX = INV_CAMERA_MATRIX * mat4(CAMERA_MATRIX[0] * length(WORLD_MATRIX[0].xyz), CAMERA_MATRIX[1] * length(WORLD_MATRIX[1].xyz), CAMERA_MATRIX[2] * length(WORLD_MATRIX[2].xyz), WORLD_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float radial = clamp(1.0 - dot(uv, uv), 0.0, 1.0);
	float lumps = noise(UV * 4.0 + seed) * 0.6 + noise(UV * 9.0 - seed) * 0.4;
	float depth = -VERTEX.z;
	float fade = smoothstep(near_fade, near_full, depth) * (1.0 - smoothstep(far_fade * 0.5, far_fade, depth));
	float glow = dither_posterize(clamp(strength * radial * radial * lumps * fade, 0.0, 1.0), FRAGCOORD.xy);
	ALBEDO = tint.rgb * glow;
}
