shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_disabled,
	
	unshaded,
	diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform vec4 albedo_detail : hint_color;
uniform vec4 albedo_detail_inner : hint_color;


uniform float rim_strength_alpha = 1.0;
uniform float rim_exponent_alpha : hint_range(0.0, 50.0, 0.1) = 5.0;

uniform float rim_strength = 1.0;
uniform float rim_exponent : hint_range(0.0, 50.0, 0.1) = 5.0;

uniform float rim_strength_detail = 1.0;
uniform float rim_exponent_detail : hint_range(0.0, 50.0, 0.1) = 10.0;

uniform float rim_strength_detail_inner = 2.0;
uniform float rim_exponent_detail_inner : hint_range(0.0, 50.0, 0.1) = 15.0;

uniform float alpha_factor = 1.0;
uniform float alpha_clip : hint_range(0,1) = 1.0;

uniform float distance_fade_min = 0.0;
uniform float distance_fade_max = 5.0;

uniform sampler2D noise;


void fragment()
{
	
	float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, 1.0);
	float rim_alpha = clamp(pow(dt, rim_exponent_alpha)*rim_strength_alpha, 1e-6, alpha_clip);
	
	float rim_detail = clamp(pow(dt, rim_exponent_detail)*rim_strength_detail, 1e-6, 1.0);
	float rim_detail_inner = clamp(pow(dt, rim_exponent_detail_inner)*rim_strength_detail_inner, 1e-6, 1.0);

	ALBEDO = albedo.rgb*rim + albedo_detail.rgb*(1.0-rim_detail) + albedo_detail_inner.rgb*(1.0-rim_detail_inner);
	ALBEDO *= COLOR.rgb;
	//ALPHA = COLOR.r*COLOR.g*COLOR.b*500.0;
	//ALPHA *= clamp(smoothstep(distance_fade_min, distance_fade_max, length(VERTEX)), 1e-6, 1.0);

	
}
