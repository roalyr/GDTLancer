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
	depth_draw_opaque;
	
uniform vec4 surface_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 rim_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);

uniform float color_clamp_up = 1.0;
uniform float color_clamp_down = -1.0;

uniform float major_phase = 2.0;
uniform float small_phase = -2.0;

uniform sampler2D major_detail_noise : hint_normal;
uniform sampler2D small_detail_noise : hint_normal;

uniform float major_detail_scale = 2;
uniform float small_detail_scale = 4;

uniform float major_detail_flow = 0.01;
uniform float small_detail_flow = 0.02;

uniform float rim_strength = 3.0;
uniform float rim_power = 3.0;
uniform float rim_intensity = 3.0;

const float pi = 3.1415926535;

void fragment()
{
	// Surface details major.
	vec2 p = texture(major_detail_noise, -UV*major_detail_scale).xy 
		-TIME*major_detail_flow;
		
	vec2 p2 = texture(small_detail_noise, -UV*small_detail_scale).xy 
		-TIME*small_detail_flow;
	
	float detail_major = sin(texture(major_detail_noise, p).r*pi+major_phase);
	float detail_small = sin(texture(small_detail_noise, p2).r*pi+small_phase);
	
	float rim = clamp(pow(dot(NORMAL, VIEW), rim_power)*rim_strength, 1e-6, 1.0);
	
	// Combine surface colors with details. Not clamping it because it makes
	// interesting effects when colors overflow.
	ALBEDO = 
		surface_color.rgb + (1.0-rim)*rim_color.rgb*rim_intensity
		+clamp((detail_major), color_clamp_down, color_clamp_up)
		+detail_small;
	//ALBEDO = vec3(DEPTH, DEPTH, DEPTH);
	// This is may be needed by alpha sorting.
	//ALPHA = 1.0;
}