shader_type spatial;

// Custom lighting model: Manual control over Light, Shadow, and Specular
render_mode 
    blend_mix, 
    cull_back, 
    depth_draw_opaque,
    specular_disabled, 
    ambient_light_disabled; 

// ==========================================
// 1. PAINT & COLORS (The Object)
// ==========================================
uniform vec4 paint_color : hint_color = vec4(1.0);

// ==========================================
// 2. LIGHTING VIBE (The Environment)
// ==========================================
// The color of the object when LIT (e.g., Warm Cream)
uniform vec4 light_tint : hint_color = vec4(1.0, 0.95, 0.9, 1.0); 
// The color of the object in SHADOW (e.g., Cold Purple/Teal)
uniform vec4 shadow_tint : hint_color = vec4(0.15, 0.15, 0.25, 1.0); 

// Moves the shadow line. < 0.0 = More Light, > 0.0 = More Shadow
uniform float shadow_bias : hint_range(-1.0, 1.0) = 0.0; 
// 0.01 = Hard Anime Line, 1.0 = Soft Painterly Gradient
uniform float shadow_softness : hint_range(0.01, 1.0) = 0.1; 
// 1.0 = Flat Lit Area (Anime), 0.0 = Detailed 3D Lit Area
uniform float shadow_normal_blend : hint_range(0.0, 1.0) = 0.5;

// ==========================================
// 3. SPECULAR IMITATION (The Shine)
// ==========================================
uniform vec4 spec_tint : hint_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform float spec_intensity : hint_range(0.0, 5.0) = 0.0;
// Higher = Smaller, tighter highlight
uniform float spec_glossiness : hint_range(1.0, 100.0) = 10.0; 
// 0.0 = Hard Edge Dot, 1.0 = Soft Bloom
uniform float spec_softness : hint_range(0.0, 1.0) = 0.1; 

// ==========================================
// 4. RIM EFFECT (The Edge)
// ==========================================
uniform vec4 rim_color : hint_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float rim_width : hint_range(0.0, 10.0) = 3.0;
uniform float rim_power : hint_range(0.0, 10.0) = 2.0;
uniform bool rim_mask_on_shadow = true; 

// ==========================================
// 5. SURFACE DETAILS (Textures)
// ==========================================
uniform sampler2D detail_texture : hint_albedo; // Green channel used for scratches/dirt
uniform sampler2D normal_texture : hint_normal;

uniform float detail_paint_scale = 1.0;
uniform float detail_paint_strength : hint_range(-1.0, 1.0) = 0.0; // Neg = Dark, Pos = Light
uniform float detail_paint_contrast : hint_range(0.1, 10.0) = 1.0;

uniform float detail_normal_scale = 1.0;
uniform float detail_normal_strength : hint_range(-5.0, 5.0) = 1.0;

// ==========================================
// 6. MAPPING (Triplanar)
// ==========================================
uniform float uv_triplanar_sharpness : hint_range(0.0, 100.0) = 10.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

// Non-linear perspective
uniform float scale_start = 3e3;
uniform float scale_end_mul = 25;
uniform float scale_power = 1.0;
uniform float scale_min = 0.25;


// --- INTERNAL VARYINGS ---
varying vec3 uv_triplanar_pos;
varying vec3 uv_power_normal;


// --- FUNCTIONS ---
vec4 triplanar_texture(sampler2D p_sampler, vec3 p_weights, vec3 p_pos) {
    vec4 samp = vec4(0.0);
    samp += texture(p_sampler, p_pos.xy) * p_weights.z;
    samp += texture(p_sampler, p_pos.xz) * p_weights.y;
    samp += texture(p_sampler, p_pos.zy * vec2(-1.0, 1.0)) * p_weights.x;
    return samp;
}

void vertex() {
	// --- Non-linear perspective (based on distance) ---
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

void light() {
    // --- 1. SHADOW / LIT CALCULATIONS ---
    float NdotL = dot(NORMAL, LIGHT);
    
    // A. The Terminator (Shadow Mask)
    // Calculates where the hard line is drawn
    float transition_start = shadow_bias - shadow_softness;
    float transition_end = shadow_bias + shadow_softness;
    float shadow_mask = smoothstep(transition_start, transition_end, NdotL);
    
    // B. The Surface Shading (Normal Map Detail)
    // Calculates the soft 3D shading
    float surface_shading = clamp(NdotL, 0.0, 1.0);
    
    // C. The Lit Color Mix
    // Blends betwen Flat Anime Color (light_tint) and Detailed 3D Color (light_tint * shading)
    vec3 lit_layer_flat = light_tint.rgb;
    vec3 lit_layer_detailed = lit_layer_flat * surface_shading;
    vec3 final_lit_layer = mix(lit_layer_detailed, lit_layer_flat, shadow_normal_blend);

    // D. Final Base Lighting
    vec3 base_lighting = mix(shadow_tint.rgb, final_lit_layer, shadow_mask);
    
    // --- 2. RIM EFFECT ---
    float NdotV = dot(NORMAL, VIEW);
    float fresnel = pow(1.0 - clamp(NdotV, 0.0, 1.0), rim_width);
    
    // Masking rim if requested
    float rim_mask = rim_mask_on_shadow ? (1.0 - shadow_mask) : 1.0;
    vec3 rim_final = rim_color.rgb * fresnel * rim_power * rim_mask;
    
    // --- 3. SPECULAR IMITATION ---
    // Blinn-Phong half-vector
    vec3 H = normalize(VIEW + LIGHT);
    float NdotH = max(0.0, dot(NORMAL, H));
    
    // Glossiness (Size of spot)
    float spec_raw = pow(NdotH, spec_glossiness);
    
    // Softness (Edge of spot)
    float spec_blob = smoothstep(0.5 - spec_softness * 0.5, 0.5 + spec_softness * 0.5, spec_raw);
    
    vec3 spec_final = spec_blob * spec_tint.rgb * spec_intensity;

    // --- 4. OUTPUT ---
    // Paint * (Lighting + Rim) + Specular
    vec3 final_color = (base_lighting + rim_final) * ATTENUATION;
    DIFFUSE_LIGHT += (ALBEDO * final_color) + (spec_final * ATTENUATION);
}