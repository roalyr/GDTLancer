// Hull scar blob (HullScars): a squashed sphere sunk into the plating, one MultiMesh instance per
// scar. Glows white-orange when hit, cools through dull red to dark char over cool_time. Unshaded:
// char is near black and the glow is its own light, so no light passes.
// With relight_min > 0 (slag, hull_slag_material.tres) a blob does not stay cold: it flares up again
// every relight_min..relight_max s (its own period, from its seed), as if the slag re-ignited.
// INSTANCE_CUSTOM: x = hit time (on the `now` clock), y = random seed, z = facing (1 head-on), w = size (m).
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
uniform float lump = 0.12;  // Bumps on the dome, as a share of the blob's size

varying float heat;

void vertex() {
	float seed = INSTANCE_CUSTOM.y * 100.0;
	float bump = sin(VERTEX.x * 9.0 + seed) * sin(VERTEX.z * 7.0 + seed * 1.7) * sin(VERTEX.y * 5.0 + seed * 2.3);
	VERTEX += NORMAL * bump * lump;
	float age = max(now - INSTANCE_CUSTOM.x, 0.0);
	float rise = 1.0;
	if (relight_min > 0.0) {
		float period = mix(relight_min, relight_max, fract(INSTANCE_CUSTOM.y * 7.31));
		if (age > period) {
			age = mod(age, period);
			rise = smoothstep(0.0, relight_rise, age);  // Re-ignites: brightens, then cools again
		}
	}
	float left = clamp(1.0 - age / cool_time, 0.0, 1.0);
	heat = rise * left * left * mix(0.8, 1.0, INSTANCE_CUSTOM.z);  // Fast fade at first, then a long dull glow
}

void fragment() {
	// Facing the camera: the dome's middle, hottest and lightest; its rim cools and darkens first,
	// so a blob reads as a lump, not a flat patch.
	float middle = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float h = heat * mix(0.45, 1.0, middle);
	vec3 glow = mix(glow_color.rgb, hot_color.rgb, h * h);
	vec3 cold = char_color.rgb * mix(0.6, 1.6, middle);
	ALBEDO = mix(cold, glow, smoothstep(0.0, 0.4, h));
}
