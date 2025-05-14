shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_add,
	cull_front,

	unshaded,
	diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform vec4 albedo_out : hint_color;

uniform sampler2D normal_detail_minor_noise;

uniform float normal_detail_factor = 1.0;
uniform float normal_detail_power = 1.0;
uniform float normal_detail_clamp = 15.0;
uniform float normal_detail_rim_strength = 1.0;
uniform float normal_detail_rim_exponent = 1.0;
uniform float normal_detail_uv1_scale = 1.0;
uniform vec3 normal_detail_uv1_offset = vec3(0.0);

uniform float out_rim_strength = 1.0;
uniform float out_rim_exponent = 1.0;

uniform float fade_albedo_near = 0;

uniform float fog_power = 1.0;

const float pi = 3.1415926535;

varying vec3 normal_detail_uv1_triplanar_pos;
uniform float uv1_blend_sharpness = 10.0;
varying vec3 uv1_power_normal;


void vertex() {
	vec3 normal = NORMAL;
	TANGENT = vec3(0.0,0.0,-1.0) * abs(normal.x);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(normal.y);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(normal.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0,1.0,0.0) * abs(normal.x);
	BINORMAL+= vec3(0.0,0.0,-1.0) * abs(normal.y);
	BINORMAL+= vec3(0.0,1.0,0.0) * abs(normal.z);
	BINORMAL = normalize(BINORMAL);
	uv1_power_normal=pow(abs(NORMAL),vec3(uv1_blend_sharpness));
	normal_detail_uv1_triplanar_pos = VERTEX * pow(2.0, normal_detail_uv1_scale) + normal_detail_uv1_offset;
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	normal_detail_uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);

}



vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,p_triplanar_pos.xy) * p_weights.z;
	samp+= texture(p_sampler,p_triplanar_pos.xz) * p_weights.y;
	samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

void fragment()
{
	// Get tangent, binormal and normal of the vertex.
	vec3 N = normalize(NORMAL);
	vec3 T = normalize(TANGENT);
	vec3 B = normalize(BINORMAL);

	// Get texture data.
	// Normal textures.
	vec4 nm_detail_minor_noise = triplanar_texture(
		normal_detail_minor_noise,
		uv1_power_normal,
		normal_detail_uv1_triplanar_pos);
		// Transform the RGB values of the normal map to the range [-1, 1].
	vec3 nm_detail_minor_noise_normalized = normalize(nm_detail_minor_noise.rgb * 2.0 - 1.0);
		// Transform normal map normal from tangent space to view space.
	vec3 nm_normal_detail_minor_view = normalize(mat3(T, B, N) * nm_detail_minor_noise_normalized);

	// Binary textures.

	// Calculate the dot product between the normal and view direction.
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float dt_normal_detail_minor = clamp(abs(dot(nm_normal_detail_minor_view, VIEW)), 1e-6, 1.0);

	// Attenuate the dot product.
	float rim_normal_detail_minor = clamp(pow(dt_normal_detail_minor, normal_detail_rim_exponent)*normal_detail_rim_strength, 1e-6, 1.0);
	float rim_out = clamp(pow(dt, out_rim_exponent)*out_rim_strength, 1e-6, 1.0);
	
	// fade distances.
	float dist = length(VERTEX);

	float fd_albedo_near = clamp(smoothstep(0.0, fade_albedo_near, dist), 1e-6, 1.0); // fades in

	// Main color
	ALBEDO = albedo.rgb * COLOR.rgb * (pow(fd_albedo_near, fog_power)) 
		* clamp(pow(rim_normal_detail_minor * normal_detail_factor, normal_detail_power), 0.0, normal_detail_clamp);
	ALBEDO += albedo_out.rgb * COLOR.rgb * (pow(fd_albedo_near, fog_power))  * (1.0 - rim_out) 
		* clamp(pow(rim_normal_detail_minor * normal_detail_factor, normal_detail_power), 0.0, normal_detail_clamp);

}