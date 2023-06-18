shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_add,
	cull_back,
	
	unshaded,
	diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

//uniform vec4 albedo : hint_color;
uniform vec4 albedo : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float size = 1.0;


void vertex()
{
	POINT_SIZE = size;
}

void fragment()
{
	ALBEDO = albedo.rgb*COLOR.rgb;
}
