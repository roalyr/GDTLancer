shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_front,
	
	unshaded,
	//diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 0.05;
uniform float rim_exponent : hint_range(0.0, 50.0, 0.1) = 15.0;
uniform float alpha_clip : hint_range(0,1) = 1.0;

void fragment()
{
	float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, alpha_clip);
	ALBEDO = albedo.rgb*COLOR.rgb;
	ALPHA = rim;
}
