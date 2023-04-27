shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_add,
	cull_disabled,
	
	unshaded,
	diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;

uniform float rim_strength = 0.05;
uniform float rim_exponent  = 15.0;

uniform float rim_strength_detail = 0.05;
uniform float rim_exponent_detail  = 15.0;

uniform float alpha_clip : hint_range(0,1) = 1.0;

uniform float distance_fade_min = 0.0;
uniform float distance_fade_max = 5.0;


void fragment()
{
	
	float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, alpha_clip);
	float rim_detail = clamp(pow(dt, rim_exponent_detail)*rim_strength_detail, 1e-6, alpha_clip);

	ALBEDO = (albedo.rgb)*(rim)*(1.0-rim_detail);
	ALBEDO *= clamp(smoothstep(distance_fade_min, distance_fade_max, length(VERTEX)), 1e-6, alpha_clip);
	ALBEDO *= COLOR.rgb;
}
