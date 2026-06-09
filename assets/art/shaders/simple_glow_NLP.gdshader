shader_type spatial;
render_mode
	vertex_lighting,
	blend_add,
	cull_front,
	unshaded,
	specular_disabled,
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 5.0;
uniform float rim_exponent = 30.0;
uniform float rim_power  = 1.0;

uniform float rim_floor  = 0.1;
uniform float rim_outer_strength = 3.0;
uniform float rim_outer_exponent = 3.0;

uniform float fade_distance_near = 100;
uniform float fade_distance_far = 1000;
uniform float fade_power = 1.0;

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

void vertex() {
	// Non-linear perspective
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
}

void fragment()
{
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_outer = clamp(pow(dt, rim_outer_exponent)*rim_outer_strength, 1e-6, 1.0);
	ALBEDO = albedo.rgb;
	ALBEDO *= rim_floor * rim_outer +  pow(rim, rim_power);
	
	// Fade near and far.
	float dist = length(VERTEX);
	float fade_out = clamp(smoothstep(fade_distance_far, 0.0, dist), 1e-6, 1.0); // fades out
	float fade_in = clamp(smoothstep(0.0, fade_distance_near, dist), 1e-6, 1.0); // fades in
	float fade = pow(fade_in*fade_out, fade_power);
	
	ALBEDO *= fade;
}
