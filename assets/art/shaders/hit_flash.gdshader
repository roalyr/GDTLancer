// Hit flash sprite: additive soft disc, billboarded, never smaller than min_screen_height on screen.
shader_type spatial;
render_mode blend_add, cull_disabled, depth_draw_never, unshaded, shadows_disabled;

uniform vec4 tint : hint_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float min_screen_height = 0.012;  // Fraction of the viewport height.

// Dither and posterization, as in the other translucent shaders (star halo / sprite values).
uniform float posterization_levels = 20.0;
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

// @common billboard
// Camera-facing quads that never shrink below `uniform float min_screen_height` (a share of the
// viewport height). In vertex():
//     MODELVIEW_MATRIX = billboard(INV_CAMERA_MATRIX, CAMERA_MATRIX, WORLD_MATRIX);
//     VERTEX *= billboard_scale(VERTEX, MODELVIEW_MATRIX, WORLD_MATRIX, PROJECTION_MATRIX);
mat4 billboard(mat4 inv_camera, mat4 camera, mat4 world) {
	return inv_camera * mat4(camera[0], camera[1], camera[2], world[3]);
}

// The node's scale, raised so the quad covers at least min_screen_height of the screen.
float billboard_scale(vec3 vertex, mat4 modelview, mat4 world, mat4 projection) {
	float world_scale = length(world[0].xyz);
	float view_distance = max(-(modelview * vec4(0.0, 0.0, 0.0, 1.0)).z, 0.001);
	float half_size = max(length(vertex.xy) * world_scale, 0.0001);
	// A world length L at distance d covers L * P[1][1] / d of the 2-unit NDC height.
	float min_half_size = min_screen_height * view_distance / projection[1][1];
	return world_scale * max(1.0, min_half_size / half_size);
}
// @end

void vertex() {
	MODELVIEW_MATRIX = billboard(INV_CAMERA_MATRIX, CAMERA_MATRIX, WORLD_MATRIX);
	VERTEX *= billboard_scale(VERTEX, MODELVIEW_MATRIX, WORLD_MATRIX, PROJECTION_MATRIX);
}

void fragment() {
	float falloff = clamp(1.0 - length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	vec4 color = COLOR * tint;
	// Additive: the brightness itself is dithered and posterized, as in the star halo.
	float value = dither_posterize(clamp(color.a * smoothstep(0.0, 1.0, falloff) * intensity, 0.0, 1.0), FRAGCOORD.xy);
	ALBEDO = color.rgb * value;
}
