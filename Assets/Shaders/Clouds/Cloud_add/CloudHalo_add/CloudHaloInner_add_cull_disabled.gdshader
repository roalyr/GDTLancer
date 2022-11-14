shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_add,
	cull_disabled,
	
	unshaded,
	//diffuse_lambert, 
	//specular_schlick_ggx,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float rim_strength = 1.5;
uniform float rim_power = 9.0;
uniform float alpha_global = 0.5;


void fragment()
{
	float rim = clamp(pow(dot(NORMAL,VIEW), rim_power)*rim_strength, 0.0, 1.0);
	ALBEDO = albedo.rgb*COLOR.rgb;
	ALPHA = clamp(1.0-rim, 0.0, 1.0)*alpha_global;
}
