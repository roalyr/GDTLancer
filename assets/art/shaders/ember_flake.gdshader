// Ember flake sprite: a small, crisp, additive flake of burning hull, like burning paper flaking
// off. Billboarded, never smaller than min_screen_height on screen; each flake flickers on its own.
// Vertex code as in hit_flash.gdshader; keep them in sync.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : hint_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float brightness = 1.6;  // Over the colour ramp: embers glow, they are not lit
uniform float min_screen_height = 0.003;  // Fraction of the viewport height.
uniform float flicker = 0.35;  // Share of the brightness that flickers
uniform float flicker_speed = 9.0;  // rad/s

varying float flick;
varying float seed;

void vertex() {
	MODELVIEW_MATRIX = INV_CAMERA_MATRIX * mat4(CAMERA_MATRIX[0], CAMERA_MATRIX[1], CAMERA_MATRIX[2], WORLD_MATRIX[3]);
	float world_scale = length(WORLD_MATRIX[0].xyz);
	float view_distance = max(-(MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).z, 0.001);
	float half_size = max(length(VERTEX.xy) * world_scale, 0.0001);
	// A world length L at distance d covers L * P[1][1] / d of the 2-unit NDC height.
	float min_half_size = min_screen_height * view_distance / PROJECTION_MATRIX[1][1];
	VERTEX *= world_scale * max(1.0, min_half_size / half_size);
	seed = dot(WORLD_MATRIX[3].xyz, vec3(0.731, 1.37, 0.913));  // Each flake its own phase and outline
	flick = 1.0 - flicker * (0.5 + 0.5 * sin(TIME * flicker_speed + seed) * sin(TIME * flicker_speed * 0.63 + seed * 2.1));
}

void fragment() {
	// A hard-edged, ragged flake of its own outline: a bright core, no soft halo.
	vec2 p = UV - vec2(0.5);
	float a = atan(p.y, p.x);
	float ragged = 0.38 + 0.06 * sin(a * 2.0 + seed) + 0.04 * sin(a * 3.0 + seed * 1.9);
	float d = length(p);
	float inside = step(d, ragged);  // Additive: black outside adds nothing (no discard, cheaper on mobile)
	vec4 color = COLOR * tint;
	float core = mix(0.55, 1.0, 1.0 - smoothstep(0.0, ragged, d));
	ALBEDO = color.rgb * color.a * core * flick * intensity * brightness * inside;
}
