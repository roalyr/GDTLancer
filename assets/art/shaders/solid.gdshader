shader_type spatial;

render_mode
    blend_mix,
    cull_back,
	specular_schlick_ggx,
    depth_draw_opaque;

// Material properties (Inputs for fragment and light functions)
uniform vec4 albedo : hint_color = vec4(1.0);
uniform vec4 emission : hint_color = vec4(0.0, 0.0, 0.0, 1.0);

uniform sampler2D texture_normal : hint_albedo;
uniform sampler2D texture_albedo : hint_albedo;

uniform float normal_strength = 0.0;
uniform float albedo_detail_strength = 0.0;
uniform float albedo_detail_power = 1.0;

uniform float specular = 0.5;
uniform float roughness = 0.9;
uniform float metallic = 0.0;

// Non-linear perspective
uniform float scale_start = 3e3;
uniform float scale_end_mul = 30;
uniform float scale_power = 1.0;
uniform float scale_min = 0.25;

varying vec3 uv_triplanar_pos;
uniform float uv_blend_sharpness : hint_range(0.0, 100.0) = 10.0;
varying vec3 uv_power_normal;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

uniform float normal_scale = 1.0;
uniform float albedo_detail_scale = 1.0;

// --- Constants ---
const float PI = 3.14159265359;


vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
    vec4 samp=vec4(0.0);
    samp+= texture(p_sampler,p_triplanar_pos.xy) * p_weights.z;
    samp+= texture(p_sampler,p_triplanar_pos.xz) * p_weights.y;
    samp+= texture(p_sampler,p_triplanar_pos.zy * vec2(-1.0,1.0)) * p_weights.x;
    return samp;
}


void vertex() {

    TANGENT = vec3(0.0,0.0,-1.0) * abs(NORMAL.x);
    TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.y);
    TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.z);
    TANGENT = normalize(TANGENT);
    BINORMAL = vec3(0.0,1.0,0.0) * abs(NORMAL.x);
    BINORMAL+= vec3(0.0,0.0,-1.0) * abs(NORMAL.y);
    BINORMAL+= vec3(0.0,1.0,0.0) * abs(NORMAL.z);
    BINORMAL = normalize(BINORMAL);
    uv_power_normal=pow(abs(NORMAL),vec3(uv_blend_sharpness));
    uv_power_normal/=dot(uv_power_normal,vec3(1.0));
    uv_triplanar_pos = VERTEX * uv_scale + uv_offset;
    uv_triplanar_pos *= vec3(1.0,-1.0, 1.0);
	
	// --- Non-linear perspective (based on distance) ---
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
}

void fragment() {
    vec3 normal_tex = triplanar_texture(texture_normal,uv_power_normal,uv_triplanar_pos * normal_scale).rgb;
    vec3 albedo_detail = triplanar_texture(texture_albedo, uv_power_normal, uv_triplanar_pos * albedo_detail_scale).rgb;
    float albedo_detail_val = albedo_detail_strength * pow(albedo_detail.g, albedo_detail_power);

    ALBEDO = albedo.rgb + albedo_detail_val;
	SPECULAR = specular;
	ROUGHNESS = roughness;
	METALLIC = metallic;
    EMISSION = emission.rgb * COLOR.rgb;
    NORMALMAP = normal_tex;
    NORMALMAP_DEPTH = normal_strength;
}