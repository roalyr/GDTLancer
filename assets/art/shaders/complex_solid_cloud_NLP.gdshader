shader_type spatial;

render_mode
	vertex_lighting,
	blend_mix,
	cull_back,
	unshaded,
	diffuse_lambert,
	specular_disabled,
	ambient_light_disabled,
	depth_draw_opaque;

uniform float vertex_mask_power = 1.0;
uniform float vertex_mask_overlay = 0.0;
uniform float albedo_strength = 1.0;
uniform float lum_weight_r = 1.0;
uniform float lum_weight_g = 1.0;
uniform float lum_weight_b = 1.0;

uniform float color_power_r = 1.0;
uniform float color_power_g = 1.0;
uniform float color_power_b = 1.0;
uniform float color_multiplier_r = 1.0;
uniform float color_multiplier_g = 1.0;
uniform float color_multiplier_b = 1.0;

uniform vec4 albedo : hint_color;
uniform vec4 albedo_near : hint_color;
uniform vec4 albedo_ambient : hint_color;
uniform vec4 albedo_rim : hint_color;

uniform float normal_intensity = 1.0;
uniform float normal_detail_power = 1.0;
uniform float normal_detail_strength = 0.1;

uniform float rim_strength = 1.0;
uniform float rim_factor = 1.0;
uniform float rim_normal_detail_factor = 1.0;
uniform float rim_exponent = 1.0;

uniform float fade_distance = 1e5;
uniform float fade_power = 2.0;

// Dither and posterization constants
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;
const float light_dither_strength = 0.5;
const float posterization_levels = 5.0;
const float dither_pixel_size = 2.0;

uniform float uv1_blend_sharpness = 10.0;

uniform float normal_detail_uv1_scale = 1.0;
uniform vec3 normal_detail_uv1_offset = vec3(0.0);

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

uniform sampler2D detail_noise;
uniform sampler2D normal_noise;

const float pi = 3.1415926535;

varying vec3 uv1_triplanar_pos;
varying vec3 normal_detail_uv1_triplanar_pos;
varying vec3 uv1_power_normal;

// --- Helper Functions ---

// 2x2 Bayer matrix lookup via arithmetic
float bayer2x2(vec2 p) {
    return p.x * 2.0 + p.y * (3.0 - 4.0 * p.x);
}

// Fast GLES2-compatible 8x8 Bayer matrix calculation without stack array allocations
float bayer8x8(vec2 screen_pos) {
    vec2 p = mod(floor(screen_pos), 8.0);
    vec2 p0 = mod(p, 2.0);
    vec2 p1 = mod(floor(p / 2.0), 2.0);
    vec2 p2 = floor(p / 4.0);
    float val = 16.0 * bayer2x2(p0) + 4.0 * bayer2x2(p1) + bayer2x2(p2);
    return val / 64.0;
}

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
	uv1_triplanar_pos = VERTEX * pow(2.0, normal_detail_uv1_scale) + normal_detail_uv1_offset;
	normal_detail_uv1_triplanar_pos = VERTEX * pow(2.0, normal_detail_uv1_scale) + normal_detail_uv1_offset;
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
	normal_detail_uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
	
	// Non-linear perspective
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
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
	// Virtual pixel coordinates for DPI-independent dither grid
	vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
	float threshold = bayer8x8(dither_pos);

	// Get tangent, binormal and normal of the vertex.
	vec3 N = normalize(NORMAL);
	vec3 T = normalize(TANGENT);
	vec3 B = normalize(BINORMAL);

	// Get texture data.
	// Normal textures.
	vec4 nm_detail_minor_noise = triplanar_texture(
		normal_noise,
		uv1_power_normal,
		normal_detail_uv1_triplanar_pos);
	vec3 nm_detail_minor_noise_normalized = normalize(nm_detail_minor_noise.rgb * 2.0 - 1.0);
	vec3 nm_normal_detail_view = sign(normal_intensity)*normalize(mat3(T, B, normal_intensity*N) * nm_detail_minor_noise_normalized);

	// Calculate the dot product between the normal and view direction.
	float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	float dt_normal_detail = clamp(abs(dot(nm_normal_detail_view, VIEW)), 1e-6, 1.0);

	// Attenuate the dot product.
	float rim_normal_detail = clamp((dt_normal_detail), 1e-6, 1.0);
	float rim = clamp(pow(dt,rim_exponent), 1e-6, 1.0);

	float luminosity = dot(COLOR.rgb, vec3(lum_weight_r, lum_weight_g, lum_weight_b));
	luminosity = max(luminosity, 0.0);

	// Calculated luminosity value
	float vertex_mask = vertex_mask_overlay + pow(luminosity, vertex_mask_power);
	if (vertex_mask < 0.01) {
		discard;
	}

	// Bi-directional Bayer dithering across quantization steps
	float levels = max(1.0, posterization_levels);
	float step_size = 1.0 / levels;
	float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;

	float q_rim = floor(clamp(rim + dither_offset, 0.0, 1.0) * levels) / levels;
	float q_nm = floor(clamp(rim_normal_detail + dither_offset, 0.0, 1.0) * levels) / levels;
	float q_mask = floor(clamp(vertex_mask + dither_offset, 0.0, 1.0) * levels) / levels;

	ALBEDO = albedo_strength * albedo.rgb * COLOR.rgb;
	
	// Emulate normal map
	float normal_mask = (1.0 - pow((1.0-q_nm) * normal_detail_power, rim_normal_detail_factor));
	ALBEDO += normal_mask * normal_detail_strength;

	// Apply rim
	float rim_mask = pow((1.0 - q_rim)*q_rim, rim_factor);
	ALBEDO += rim_strength * rim_mask * albedo_rim.rgb;
	
	// Apply vertex mask
	ALBEDO *= q_mask;
	
	// color tweak.
	ALBEDO = vec3(
		pow(ALBEDO.r, color_power_r)*color_multiplier_r,
		pow(ALBEDO.g, color_power_g)*color_multiplier_g,
		pow(ALBEDO.b, color_power_b)*color_multiplier_b
	);

	// Overlay dark parts
	ALBEDO += (1.0 - clamp(q_mask, 0.0, 1.0)) * albedo_ambient.rgb;
	
	// Replace near parts with ambient color to hide polygons.
	float dist = length(VERTEX);
	float fade = pow(clamp(smoothstep(0.0, fade_distance, dist), 1e-6, 1.0), fade_power); // fades in
	float q_fade = floor(clamp(fade + dither_offset, 0.0, 1.0) * levels) / levels;
	vec3 current = ALBEDO;
	ALBEDO = (1.0-q_fade) * (albedo_near.rgb * q_mask) 
		+ (1.0-q_fade) * (albedo_ambient.rgb * (1.0 - q_mask)) 
		+ q_fade * current;
}