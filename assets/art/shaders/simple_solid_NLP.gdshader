shader_type spatial;

// Custom lighting model: Manual control over Light, Shadow, and Specular
render_mode 
    blend_mix, 
    cull_back, 
    depth_draw_opaque; 

uniform vec4 paint_color : hint_color = vec4(1.0);

uniform sampler2D detail_texture : hint_albedo; // Green channel used for scratches/dirt
uniform sampler2D normal_texture : hint_normal;

uniform float detail_paint_scale = 1.0;
uniform float detail_paint_strength : hint_range(-1.0, 1.0) = 0.0; // Neg = Dark, Pos = Light
uniform float detail_paint_contrast : hint_range(0.1, 10.0) = 1.0;

uniform float detail_normal_scale = 1.0;
uniform float detail_normal_strength : hint_range(-5.0, 5.0) = 1.0;

uniform float rim_strength = 1.0;
uniform float rim_exponent = 3.0;
uniform float rim_intensity = 0.3;

// Fade start and end distances (for LOD discard dithering)
uniform float fade_start = 300000.0;
uniform float fade_end_mul = 5.0;
uniform float fade_power = 2.0;

// Dither threshold for distance fade
uniform float dither_threshold : hint_range(0.0, 1.0) = 0.5;

// Dither and posterization constants
const float light_dither_strength = 0.5;
const float posterization_levels = 5.0;
const float dither_pixel_size = 2.0;

uniform float uv_triplanar_sharpness : hint_range(0.0, 100.0) = 10.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

varying vec3 uv_triplanar_pos;
varying vec3 uv_power_normal;

// --- Helper Functions ---

// Triplanar texture sampling
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_pos) {
    vec4 samp = vec4(0.0);
    samp += texture(p_sampler, p_pos.xy) * p_weights.z;
    samp += texture(p_sampler, p_pos.xz) * p_weights.y;
    samp += texture(p_sampler, p_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
    return samp;
}

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

// --- Vertex Function ---
void vertex() {
	// Non-linear perspective
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
	
    // Standard TBN generation for Triplanar
    TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
    TANGENT = normalize(TANGENT);
    BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x);
    BINORMAL += vec3(0.0, 0.0, -1.0) * abs(NORMAL.y);
    BINORMAL += vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
    BINORMAL = normalize(BINORMAL);
    
    // Triplanar Weights
    uv_power_normal = pow(abs(NORMAL), vec3(uv_triplanar_sharpness));
    uv_power_normal /= dot(uv_power_normal, vec3(1.0));
    
    // World Position Mapping
    uv_triplanar_pos = VERTEX * uv_scale + uv_offset;
    uv_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

// --- Fragment Function ---
void fragment() {
    // Virtual pixel coordinates for DPI-independent dither grid
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);

    // --- Distance-based LOD Discard Dithering ---
    float distance_vert = length(VERTEX);
    float fade_range = fade_end_mul * fade_start - fade_start;
    if (fade_range > 0.0 && distance_vert > fade_start) {
        float fade_factor = pow(clamp((fade_end_mul * fade_start - distance_vert) / fade_range, 0.0, 1.0), fade_power);
        float bayer_val = bayer8x8(dither_pos);
        if (fade_factor < bayer_val * dither_threshold + 1e-6) {
            discard;
        }
    }

    // 1. Normals
    vec3 normal_tex = triplanar_texture(normal_texture, uv_power_normal, uv_triplanar_pos * detail_normal_scale).rgb;
    NORMALMAP = normal_tex;
    NORMALMAP_DEPTH = detail_normal_strength;
    
    // 2. Details (Scratches/Dirt)
    // Sample texture
    vec4 detail_raw = triplanar_texture(detail_texture, uv_power_normal, uv_triplanar_pos * detail_paint_scale);
    // Use Green channel + Contrast
    float detail_val = pow(detail_raw.g, detail_paint_contrast);
    
    // 3. Apply Paint
    // Base Color + (Detail * Strength). Clamped to avoid negative colors.
    ALBEDO = max(paint_color.rgb + (vec3(detail_val) * detail_paint_strength), vec3(0.0));
}

// --- Light Function ---
void light() {
    // Virtual pixel coordinates for DPI-independent dither grid
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);

    // 8x8 Bayer threshold based on scaled screen-space coordinates
    float threshold = bayer8x8(dither_pos);

    // Standard Lambertian intensity
    float NoL = max(0.0, dot(NORMAL, LIGHT));

    // Bi-directional Bayer dithering across quantization steps
    float levels = max(1.0, posterization_levels);
    float step_size = 1.0 / levels;
    float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
    float dithered_NoL = clamp(NoL + dither_offset, 0.0, 1.0);

    // Quantized toon diffuse intensity
    float quantized_NoL = floor(dithered_NoL * levels) / levels;

    // Grazing angle Fresnel rim lighting (active in light)
    float fresnel = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
    float rim = pow(fresnel, rim_exponent) * rim_strength * rim_intensity;

    // Combined diffuse lighting tinted by albedo
    vec3 current_light = ALBEDO * (quantized_NoL + rim * quantized_NoL) * ATTENUATION * LIGHT_COLOR;

    DIFFUSE_LIGHT += current_light;
    SPECULAR_LIGHT += vec3(0.0);
}
