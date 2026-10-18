// Explosion cloud puff, drawn on the spheroid shapes (assets/models/shapes, sphere-mapped normals):
// dense where it faces the camera, thinning to nothing at its rim, so a solid spheroid reads as a
// soft ball of gas. `opacity` and `heat` are animated per puff (WreckExplosionEffect): it starts
// hot orange and cools to dust grey as it grows and fades. Dithered and posterized like the other
// translucent effects.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 hot_color : hint_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform vec4 smoke_color : hint_color = vec4(0.45, 0.43, 0.41, 1.0);
uniform float heat : hint_range(0.0, 1.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float edge_softness = 1.6;  // Higher: a thinner rim, a denser core

uniform float posterization_levels = 20.0;
uniform float light_dither_strength = 0.5;
uniform float dither_pixel_size = 2.0;

float bayer2x2(vec2 p) {
	return p.x * 2.0 + p.y * (3.0 - 4.0 * p.x);
}

float bayer8x8(vec2 screen_pos) {
	vec2 p = mod(floor(screen_pos), 8.0);
	vec2 p0 = mod(p, 2.0);
	vec2 p1 = mod(floor(p / 2.0), 2.0);
	vec2 p2 = floor(p / 4.0);
	float val = 16.0 * bayer2x2(p0) + 4.0 * bayer2x2(p1) + bayer2x2(p2);
	return val / 64.0;
}

float dither_posterize(float value, vec2 fragcoord) {
	float threshold = bayer8x8(fragcoord / max(1.0, dither_pixel_size));
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dithered = clamp(value + (threshold - 0.5) * step_size * light_dither_strength, 0.0, 1.0);
	return floor(dithered * levels) / levels;
}

void fragment() {
	float density = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), edge_softness);
	ALBEDO = mix(smoke_color.rgb, hot_color.rgb, heat);
	ALPHA = dither_posterize(density * opacity, FRAGCOORD.xy);
}
