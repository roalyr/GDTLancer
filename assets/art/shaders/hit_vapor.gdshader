// Hit vapour / smoke sprite: blended soft puff, billboarded, never smaller than min_screen_height.
// Shares its vertex and dither code with hit_flash.gdshader; keep them in sync.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : hint_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float min_screen_height = 0.012;  // Fraction of the viewport height.

// Dither and posterization, as in the other translucent shaders (star halo / sprite values).
uniform float posterization_levels = 20.0;
uniform float light_dither_strength = 0.5;
uniform float dither_pixel_size = 2.0;

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
	MODELVIEW_MATRIX = INV_CAMERA_MATRIX * mat4(CAMERA_MATRIX[0], CAMERA_MATRIX[1], CAMERA_MATRIX[2], WORLD_MATRIX[3]);
	float world_scale = length(WORLD_MATRIX[0].xyz);
	float view_distance = max(-(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z, 0.001);
	float half_size = max(length(VERTEX.xy) * world_scale, 0.0001);
	// A world length L at distance d covers L * P[1][1] / d of the 2-unit NDC height.
	float min_half_size = min_screen_height * view_distance / PROJECTION_MATRIX[1][1];
	VERTEX *= world_scale * max(1.0, min_half_size / half_size);
}

void fragment() {
	float falloff = clamp(1.0 - length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	vec4 color = COLOR * tint;
	ALBEDO = color.rgb;
	// Translucent: the opacity is dithered and posterized, so puffs band like the nebulae.
	ALPHA = dither_posterize(clamp(color.a * smoothstep(0.0, 1.0, falloff) * intensity, 0.0, 1.0), FRAGCOORD.xy);
}
