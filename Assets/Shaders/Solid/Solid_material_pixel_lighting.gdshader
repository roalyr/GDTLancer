shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	//vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_back,
	
	//unshaded,
	diffuse_lambert, 
	specular_phong,
	
	// Additional flags just in case.
	//ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform vec4 emission : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float specular : hint_range(0,1) = 0.5;
uniform float metallic : hint_range(0,1) = 0.0;
uniform float roughness : hint_range(0,1) = 0.5;


void fragment()
{
	ALBEDO = albedo.rgb*COLOR.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	EMISSION = emission.rgb*COLOR.rgb;
}
