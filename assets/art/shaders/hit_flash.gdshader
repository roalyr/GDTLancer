// Hit flash sprite: additive soft disc, billboarded, never smaller than min_screen_height on screen.
// Keep the vertex code in sync with hit_vapor.gdshader.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : hint_color = vec4(1.0);
uniform float intensity = 1.0;
uniform float min_screen_height = 0.012;  // Fraction of the viewport height.

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
	ALPHA = color.a * smoothstep(0.0, 1.0, falloff) * intensity;
}
