// Explosion cloud (WreckExplosionEffect puffs, on a sphere mesh): a billowing ball of burning
// gas that cools to smoke. Its own shader, not the shared glow one: front faces only (no
// cull_front), blended rather than added, so smoke can be darker than space behind it.
// - The surface billows: fixed lumps (vertex noise from the puff's seed); the puff only swells.
// - Thick where it faces the camera, thin at the rim: soft edges without a texture.
// - `heat` (0..1, set per puff) blends smoke -> flame -> white-hot core; lumps facing the camera
//   stay hot longest, so the fire breaks up into patches as it cools.
// - Opacity is dithered and posterized, so it bands like the nebulae and hit vapour.
shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform float heat = 1.0;  // 1 just exploded .. 0 cold smoke
uniform float opacity = 1.0;
uniform float seed = 0.0;  // Per puff, so puffs billow differently
uniform float billow = 0.07;  // Lump height, as a share of the radius (small: a round ball)
uniform vec4 core_color : hint_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform vec4 flame_color : hint_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 smoke_color : hint_color = vec4(0.3, 0.28, 0.27, 1.0);

// Dither and posterization, as in the other translucent shaders (star halo / sprite values).
uniform float posterization_levels = 16.0;
uniform float dither_strength = 0.6;

varying float lumps;

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

void vertex() {
	vec3 p = normalize(VERTEX);
	float n = sin(p.x * 5.0 + seed) * sin(p.y * 4.0 + seed * 1.3) * sin(p.z * 6.0 + seed * 0.7)
		+ 0.5 * sin(p.x * 11.0 + seed * 2.1) * sin(p.z * 9.0 + seed * 1.7);
	lumps = n;
	VERTEX += NORMAL * n * billow * length(VERTEX);
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float h = clamp(heat * (0.55 + 0.45 * facing) + heat * lumps * 0.3, 0.0, 1.0);
	vec3 fire = mix(flame_color.rgb, core_color.rgb, smoothstep(0.6, 1.0, h));
	ALBEDO = mix(smoke_color.rgb, fire, smoothstep(0.05, 0.45, h));
	float thick = smoothstep(0.0, 0.7, facing);
	ALPHA = dither_posterize(clamp(opacity * thick, 0.0, 1.0), FRAGCOORD.xy);
}
