shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_mix,
	cull_back,
	
	//unshaded,
	diffuse_oren_nayar, 
	specular_phong,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float specular : hint_range(0,1) = 0.0;
uniform float metallic : hint_range(0,1) = 0.0;
uniform float roughness : hint_range(0,1) = 1.0;

uniform sampler2D displacement_texture : hint_normal;
uniform float displacement_scale = 0.01;

uniform sampler2D major_detail_noise : hint_normal;
uniform float major_detail_amount = 0.1;

uniform sampler2D small_detail_noise : hint_normal;
uniform float small_detail_amount = 0.1;
uniform float small_detail_scale = 10;

uniform sampler2D lava_detail_noise : hint_normal;
uniform float lava_detail_amount = 1.0;
uniform float lava_detail_intensity = 1.0;
uniform float lava_detail_scale = 4;
uniform float lava_noise_blend = 0.2;
uniform float lava_contrast = 1.0;
uniform float lava_flow = 0.01;

uniform float uv_shift_x = 0.0;
uniform float uv_shift_y = 0.0;

const float pi = 3.1415926535;

void vertex() {
	vec2 tex_position_x = VERTEX.yz / 1.0;
	vec2 tex_position_y = VERTEX.xz / 1.0;
	vec2 tex_position_z = VERTEX.xy / 1.0;
	
	float displacement_x = 2.0*texture(displacement_texture, tex_position_x).r-1.0;
	float displacement_y = 2.0*texture(displacement_texture, tex_position_y).r-1.0;
	float displacement_z = 2.0*texture(displacement_texture, tex_position_z).r-1.0;
	
	VERTEX.z += displacement_z * displacement_scale;
	VERTEX.x += displacement_x * displacement_scale;
	VERTEX.y += displacement_y * displacement_scale;
	UV.x *= 0.5; UV.x += uv_shift_x;
	UV.y *= 0.5; UV.y += uv_shift_y;
}

void fragment()
{
	// Surface details major.
	vec2 p = texture(major_detail_noise, -UV*2.0).xy;
	vec2 p2 = texture(small_detail_noise, -UV*small_detail_scale).xy;
	vec2 p3 = texture(lava_detail_noise, -UV*lava_detail_scale).xy -TIME*lava_flow;
	
	float detail_major = sin(texture(major_detail_noise, p).r*pi+major_detail_amount);
	float detail_small = sin(texture(small_detail_noise, p2).r*pi+small_detail_amount);
	float detail_lava = sin(texture(lava_detail_noise, p3).r*pi+lava_detail_amount);
	
	vec4 albedo_tex = texture(displacement_texture, UV);
	float lava = clamp(
			detail_lava
			-clamp(pow(detail_major, lava_noise_blend),1e-6, 1.0)*lava_contrast
		,1e-6, 0.5)*lava_detail_intensity;
	
	ALBEDO = albedo.rgb*detail_major*detail_small;
	SPECULAR = specular;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = vec3(lava, 0.0, 0.0);
}
