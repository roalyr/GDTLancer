// Hull scar blob (HullScars): a squashed sphere sunk into the plating, one MultiMesh instance per
// scar. Glows white-orange when hit, cools through dull red to dark char over cool_time. Unshaded:
// char is near black and the glow is its own light, so no light passes.
// INSTANCE_CUSTOM: x = hit time (on the `now` clock), y = random seed, z = facing (1 head-on), w = size (m).
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float now = 0.0;  // HullScars.clock(), set by HullScars while any scar is hot
uniform float cool_time = 8.0;  // s; Constants.HULL_SCAR_COOL_TIME
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
	float left = clamp(1.0 - age / cool_time, 0.0, 1.0);
	heat = left * left * mix(0.5, 1.0, INSTANCE_CUSTOM.z);  // Fast fade at first, then a long dull glow
}

void fragment() {
	vec3 glow = mix(glow_color.rgb, hot_color.rgb, heat * heat);
	ALBEDO = mix(char_color.rgb, glow, smoothstep(0.0, 0.5, heat));
}
