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
	ALBEDO = tint.rgb * strength * radial * radial * lumps * fade;
}
