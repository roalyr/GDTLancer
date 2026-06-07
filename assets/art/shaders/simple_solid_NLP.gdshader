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


vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_pos) {
    vec4 samp = vec4(0.0);
    samp += texture(p_sampler, p_pos.xy) * p_weights.z;
    samp += texture(p_sampler, p_pos.xz) * p_weights.y;
    samp += texture(p_sampler, p_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
    return samp;
}

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

void fragment() {
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
