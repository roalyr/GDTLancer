// Explosion cloud (WreckExplosionEffect puffs, on the spheroid model): a billowing ball of burning
// gas that cools to smoke. Its own shader, not the shared glow one: front faces only (no
// cull_front), blended rather than added, so smoke can be darker than space behind it.
// - The surface billows: lumps (vertex noise) that churn slowly with TIME.
// - Thick where it faces the camera, thin at the rim: soft edges without a texture.
// - `heat` (0..1, set per puff) blends smoke -> flame -> white-hot core; lumps facing the camera
//   stay hot longest, so the fire breaks up into patches as it cools.
// - Opacity is dithered and posterized, so it bands like the nebulae and hit vapour.
shader_type spatial;
render_mode blend_mix, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform float heat = 1.0;  // 1 just exploded .. 0 cold smoke
uniform float opacity = 1.0;
uniform float seed = 0.0;  // Per puff, so puffs billow differently
uniform float billow = 0.22;  // Lump height, as a share of the radius
uniform float churn = 0.35;  // How fast the lumps roll (rad/s)
uniform vec4 core_color : hint_color = vec4(1.0, 0.92, 0.7, 1.0);
uniform vec4 flame_color : hint_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 smoke_color : hint_color = vec4(0.3, 0.28, 0.27, 1.0);

// Dither and posterization, as in the other translucent shaders (star halo / sprite values).
uniform float posterization_levels = 16.0;
uniform float light_dither_strength = 0.6;
uniform float dither_pixel_size = 2.0;

varying float lumps;

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

// Bi-directional Bayer dithering, then posterization.
float dither_posterize(float value, vec2 fragcoord) {
	float threshold = bayer8x8(fragcoord / max(1.0, dither_pixel_size));
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dithered = clamp(value + (threshold - 0.5) * step_size * light_dither_strength, 0.0, 1.0);
	return floor(dithered * levels) / levels;
}

void vertex() {
	vec3 p = normalize(VERTEX);
	float t = TIME * churn + seed;
	float n = sin(p.x * 5.0 + t) * sin(p.y * 4.0 - t * 0.7 + seed) * sin(p.z * 6.0 + t * 0.5)
		+ 0.5 * sin(p.x * 11.0 - t * 1.3) * sin(p.z * 9.0 + t + seed * 2.0);
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
