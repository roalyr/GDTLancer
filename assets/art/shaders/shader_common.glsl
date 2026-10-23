// Shared shader code. Godot 3 shaders cannot include files, so each shader carries copies of the
// blocks it uses, between "// @common <name>" and "// @end" lines. Edit a block here, then run
//     python3 tools/sync_shader_blocks.py
// to copy it into every shader; test_shader_blocks.gd fails while any copy differs.
// Not a shader itself: Godot does not load this file.

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

// @common nlp
// Non-linear perspective: from scale_start out to scale_start * scale_end_mul from the camera, a
// mesh shrinks about its origin to scale_min of its size (scale_power shapes the curve), so huge,
// far bodies stay inside the camera's range. Call in vertex(): VERTEX = nlp_scale(VERTEX, MODELVIEW_MATRIX).
uniform float scale_start = 100000.0;
uniform float scale_end_mul = 100.0;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

vec3 nlp_scale(vec3 vertex, mat4 modelview) {
	float distance_vert = -(modelview * vec4(vertex, 1.0)).z;
	float scale_factor = pow(clamp((scale_end_mul * scale_start - distance_vert) / (scale_end_mul * scale_start - scale_start), scale_min, 1.0), scale_power);
	return vertex * scale_factor;
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
