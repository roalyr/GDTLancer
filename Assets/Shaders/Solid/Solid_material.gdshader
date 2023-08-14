shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_back,
	
	//unshaded,
	diffuse_lambert, 
	//specular_disabled,
	
	// Additional flags just in case.
	//ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform vec4 emission : hint_color;
uniform vec4 albedo_specular : hint_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 albedo_gloss : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 500.0, 0.1) = 1.0;


uniform float albedo_strength : hint_range(0.0, 1.0) = 1.0;
uniform float albedo_exponent : hint_range(0.0, 50.0, 0.1) = 1.0;

uniform float specular_strength : hint_range(0.0, 1.0) = 0.3;
uniform float specular_exponent : hint_range(0.0, 100.0, 0.1) = 5.0;

uniform float gloss_strength : hint_range(0.0, 1.0) = 0.5;
uniform float gloss_exponent : hint_range(0.0, 500.0, 0.1) = 500.0;

uniform float albedo_clip : hint_range(0,1) = 1.0;
uniform float specular_clip : hint_range(0,1) = 1.0;
uniform float gloss_clip : hint_range(0,1) = 1.0;

void fragment()
{
	
	float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float albedo_rim = clamp(pow(dt, albedo_exponent)*albedo_strength, 1e-6, albedo_clip);
	float specular_rim = clamp(pow(dt, specular_exponent)*specular_strength, 1e-6, specular_clip);
	float gloss_rim = clamp(pow(dt, gloss_exponent)*gloss_strength, 1e-6, gloss_clip);
	

	ALBEDO = albedo.rgb*albedo_rim + albedo_specular.rgb*specular_rim + albedo_gloss.rgb*gloss_rim;
	ALBEDO *= COLOR.rgb;
	EMISSION = emission.rgb * COLOR.rgb * emission_strength;
}
