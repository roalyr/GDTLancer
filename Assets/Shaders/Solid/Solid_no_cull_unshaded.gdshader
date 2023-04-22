shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	//vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_disabled,
	
	unshaded,
	//diffuse_lambert, 
	//specular_schlick_ggx,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform vec4 emission : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float specular : hint_range(0,1) = 0.5;
uniform float metallic : hint_range(0,1) = 0.0;
uniform float roughness : hint_range(0,1) = 0.5;
uniform float rim : hint_range(0,1) = 0.01;
uniform float rim_tint : hint_range(0,1) = 0.0;

void fragment()
{
	ALBEDO = albedo.rgb*COLOR.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	//RIM = rim;
	//RIM_TINT = rim_tint;
	//EMISSION = emission.rgb*COLOR.rgb;
}
