// Hull scar blobs (HullScars): squashed spheres sunk into the plating, all of a ship's merged into
// one mesh (lumps and placement baked on the CPU). Glows white-orange when hit, cools through dull
// red to dark char over cool_time. Unshaded:
// char is near black and the glow is its own light, so no light passes.
// With relight_min > 0 (slag, hull_slag_material.tres) a blob does not stay cold: it flares up again
// every relight_min..relight_max s (its own period, from its seed), as if the slag re-ignited.
// Per vertex (the same for a whole blob): UV2.x = hit time (on the `now` clock), UV2.y = random
// seed, COLOR.r = facing (1 head-on).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float now = 0.0;  // HullScars.clock(), set by HullScars while any scar is hot or slag is on
uniform float cool_time = 20.0;  // s; Constants.HULL_SCAR_COOL_TIME / HULL_SLAG_COOL_TIME
uniform float relight_min = 0.0;  // s between flare-ups, shortest; 0: never (scars)
uniform float relight_max = 0.0;  // s, longest
uniform float relight_rise = 0.6;  // s a flare-up takes to brighten
uniform vec4 char_color : hint_color = vec4(0.05, 0.045, 0.04, 1.0);
uniform vec4 glow_color : hint_color = vec4(0.75, 0.16, 0.03, 1.0);  // Cooling: dull red
uniform vec4 hot_color : hint_color = vec4(1.0, 0.85, 0.55, 1.0);  // Just hit: white-orange

// Dither and posterization, as in the other shaders (star halo / sprite values).
uniform float posterization_levels = 8.0;
uniform float dither_strength = 0.9;

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

varying float heat;

void vertex() {
	float age = max(now - UV2.x, 0.0);
	float rise = 1.0;
	if (relight_min > 0.0) {
		float period = mix(relight_min, relight_max, fract(UV2.y * 7.31));
		if (age > period) {
			age = mod(age, period);
			rise = smoothstep(0.0, relight_rise, age);  // Re-ignites: brightens, then cools again
		}
	}
	float left = clamp(1.0 - age / cool_time, 0.0, 1.0);
	heat = rise * left * left * mix(0.8, 1.0, COLOR.r);  // Fast fade at first, then a long dull glow
}

void fragment() {
	// Facing the camera: the dome's middle, hottest and lightest; its rim cools and darkens first,
	// so a blob reads as a lump, not a flat patch.
	// Heat and shading are dithered and posterized, so blobs band like the hull they sit on.
	float middle = dither_posterize(clamp(dot(NORMAL, VIEW), 0.0, 1.0), FRAGCOORD.xy);
	float h = dither_posterize(heat * mix(0.45, 1.0, middle), FRAGCOORD.xy);
	vec3 glow = mix(glow_color.rgb, hot_color.rgb, h * h);
	vec3 cold = char_color.rgb * mix(0.6, 1.6, middle);
	ALBEDO = mix(cold, glow, smoothstep(0.0, 0.4, h));
}
