shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_back,
	
	unshaded,
	//diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 rim_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 overlay_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 surface_color : hint_color = vec4(1.0, 1.0, 0.0, 1.0);

uniform float major_phase : hint_range(0, 3.14) = 1.1;

uniform float major_detail_intensity = 0.5;
uniform float detail_decay_distance = 1e12;

uniform sampler2D major_detail_noise : hint_normal;

uniform float major_detail_scale : hint_range(1.0, 10.0, 1.0) = 1;

uniform float major_detail_flow = 0.01;

uniform float rim_strength = 1.0;
uniform float rim_exponent : hint_range(0.0, 50.0, 0.1) = 0.5;
uniform float rim_intensity = 0.3;

const float pi = 3.1415926535;
const vec3 WHITE = vec3(1.0,1.0,1.0);



void fragment()
{
	vec2 p = texture(major_detail_noise, -UV*2.0*major_detail_scale).xy -TIME*major_detail_flow;
	float detail_major = sin(texture(major_detail_noise, p).r*pi+major_phase);
	float rim = clamp(pow(dot(NORMAL, VIEW), rim_exponent)*rim_strength, 1e-6, 1.0);
	
	ALBEDO = 
		+ detail_major * WHITE * major_detail_intensity
		+ length(VERTEX)/detail_decay_distance;
		
	ALBEDO += overlay_color.rgb;
	ALBEDO *= surface_color.rgb;
	ALBEDO += (1.0-rim)*rim_color.rgb*rim_intensity;
	
}