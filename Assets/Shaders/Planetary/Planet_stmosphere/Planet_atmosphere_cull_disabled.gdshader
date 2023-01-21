shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_disabled,
	
	//unshaded,
	diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float alpha_clip : hint_range(0,1) = 0.1;
uniform float rim_strength = 0.1;
uniform float rim_power = 1.0;

void fragment()
{
	float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = clamp(pow(dt,rim_power)*rim_strength, 1e-6, alpha_clip);
	ALBEDO = albedo.rgb;
	ALPHA = rim;
}
