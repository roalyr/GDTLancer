shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_add,
	cull_front,
	
	unshaded,
	//diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 1.5;
uniform float rim_exponent : hint_range(0.0, 50.0, 0.1) = 9.0;
uniform float rim_strength_inner = 1.5;
uniform float rim_exponent_inner : hint_range(0.0, 50.0, 0.1) = 9.0;
uniform float alpha_clip : hint_range(0.0, 1.0) = 1.0;
uniform float alpha_clip_inner : hint_range(0.0, 1.0) = 1.0;

void fragment()
{
	float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, alpha_clip);
	float rim_inner = clamp(pow(dt, rim_exponent_inner)*rim_strength_inner, 1e-6, alpha_clip_inner);
	ALBEDO = albedo.rgb*COLOR.rgb;
	ALPHA = clamp(1.0-rim_inner, 1e-6, 1.0)*clamp(rim, 1e-6, 1.0);
}
