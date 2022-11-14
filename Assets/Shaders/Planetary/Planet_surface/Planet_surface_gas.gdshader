shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_back,
	
	//unshaded,
	diffuse_oren_nayar, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;
	
uniform vec4 albedo : hint_color;
uniform vec4 albedo_bands : hint_color;

uniform sampler2D major_detail_noise : hint_normal;
uniform float major_detail_stretch_x = 1.0;
uniform float major_detail_stretch_y = 10.0;
uniform float major_detail_amount = 1.0;
uniform float major_detail_scale = 1.0;

uniform sampler2D bands_noise : hint_normal;
uniform float bands_amount = 1.0;
uniform float bands_stretch_x = 0.0;
uniform float bands_stretch_y = 10.0;

uniform float uv_shift_x = 0.0;
uniform float uv_shift_y = 0.0;

const float pi = 3.1415926535;


void fragment()
{
	// Surface details.
	vec2 p1 = texture(major_detail_noise, 
		-vec2(
			UV.x*major_detail_stretch_x*major_detail_scale, 
			UV.y*major_detail_stretch_y*major_detail_scale)).xy;

	vec2 p2 = texture(bands_noise, 
		-vec2(
			UV.x*bands_stretch_x, 
			UV.y*bands_stretch_y)).xy;
			
	float detail_bands = sin(texture(bands_noise, p2).r*pi+bands_amount);
	float detail_major = sin(texture(major_detail_noise, p1).r*pi+major_detail_amount);
	
	ALBEDO = albedo_bands.rgb*detail_bands+albedo.rgb*detail_major;
}
