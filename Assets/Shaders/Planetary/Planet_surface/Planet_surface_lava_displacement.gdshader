shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_back,
	
	//unshaded,
	diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;

uniform sampler2D major_detail_noise : hint_normal;
uniform sampler2D small_detail_noise : hint_normal;
//uniform sampler2D micro_detail_noise : hint_normal;
uniform sampler2D lava_detail_noise : hint_normal;

uniform float major_detail_phase = 1.5;
uniform float small_detail_phase = 1.0;
//uniform float micro_detail_phase = 0.4;
uniform float lava_detail_phase = 1.0;

uniform float major_detail_scale : hint_range(1.0, 10.0, 1.0) = 10;
uniform float small_detail_scale : hint_range(1.0, 10.0, 1.0) = 10;
//uniform float micro_detail_scale : hint_range(1.0, 10.0, 1.0)= 10;
uniform float lava_detail_scale : hint_range(1.0, 100.0, 1.0) = 100;

uniform float lava_detail_intensity = 1.0;
uniform float lava_noise_blend = 0.7;
uniform float lava_contrast = 3.0;
uniform float lava_flow = 0.01;

uniform float uv_shift_x = 0.0;
uniform float uv_shift_y = 0.0;

const float pi = 3.1415926535;

void vertex() {
	UV.x *= 0.5; UV.x += uv_shift_x;
	UV.y *= 0.5; UV.y += uv_shift_y;
}

void fragment()
{
	// Surface details major.
	vec2 p = texture(major_detail_noise, -UV*major_detail_scale).xy;
	vec2 p2 = texture(small_detail_noise, -UV*small_detail_scale).xy;
	//vec2 p2_1 = texture(micro_detail_noise, -UV*micro_detail_scale).xy;
	vec2 p3 = texture(lava_detail_noise, -UV*lava_detail_scale).xy -TIME*lava_flow;
	
	float detail_major = sin(texture(major_detail_noise, p).r*pi+major_detail_phase);
	float detail_small = sin(texture(small_detail_noise, p2).r*pi+small_detail_phase);
	//float detail_micro = sin(texture(micro_detail_noise, p2_1).r*pi+micro_detail_phase);
	float detail_lava = sin(texture(lava_detail_noise, p3).r*pi+lava_detail_phase);
	
	float lava = clamp(
			detail_lava
			-clamp(pow(detail_major, lava_noise_blend),1e-6, 1.0)*lava_contrast,
		1e-6, 0.5)*lava_detail_intensity;
	
	ALBEDO = albedo.rgb*detail_major*detail_small;//*detail_micro;
	EMISSION = vec3(lava, 0.0, 0.0)*detail_small;
}
