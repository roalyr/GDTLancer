shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_back,
	
	unshaded,
	//diffuse_lambert, 
	//specular_schlick_ggx,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_never;

uniform vec4 albedo : hint_color;


void fragment() {
	ALBEDO = albedo.rgb;
	DEPTH = 1.0;
}
