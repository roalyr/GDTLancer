shader_type spatial;

// Custom lighting model
render_mode 
    blend_mix, 
    cull_back, 
    depth_draw_opaque,
    specular_disabled, 
    ambient_light_disabled; 

// --- GEOMETRY & TEXTURES ---
// Base color (Paint)
uniform vec4 albedo : hint_color = vec4(1.0);

// Detail Texture (Scratches/Dirt) - Only One Texture
uniform sampler2D texture_albedo : hint_albedo;
uniform sampler2D texture_normal : hint_normal;

// Triplanar & Detail Settings
uniform float normal_strength : hint_range(-5.0, 5.0) = 1.0;
uniform float normal_scale = 1.0;

// Detail Controls
uniform float albedo_detail_scale = 1.0;
uniform float albedo_detail_strength : hint_range(-1.0, 1.0) = 0.0; // Negative = Dark details
uniform float albedo_detail_power : hint_range(0.1, 10.0) = 1.0; // Contrast of details

uniform float triplanar_sharpness : hint_range(0.0, 100.0) = 10.0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

// --- VIBE LIGHTING SETTINGS ---

// 1. The Paint Palette
uniform vec4 lit_tint : hint_color = vec4(1.0, 0.95, 0.9, 1.0); 
uniform vec4 shadow_tint : hint_color = vec4(0.15, 0.15, 0.25, 1.0); 

// 2. The Terminator (Shadow Shape)
uniform float shadow_softness : hint_range(0.01, 1.0) = 0.1; 
uniform float shadow_bias : hint_range(-1.0, 1.0) = 0.0; 

// 3. Lit Area Detail
// 1.0 = Flat Anime Look, 0.0 = Detailed 3D Look
uniform float lit_normal_softness : hint_range(0.0, 1.0) = 0.5;

// 4. The Rim
uniform vec4 rim_color : hint_color = vec4(0.5, 0.7, 1.0, 1.0);
uniform float rim_width : hint_range(0.0, 10.0) = 3.0;
uniform float rim_power : hint_range(0.0, 10.0) = 2.0;
uniform bool rim_on_shadow_only = true; 


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
    TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
    TANGENT = normalize(TANGENT);
    BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x);
    BINORMAL += vec3(0.0, 0.0, -1.0) * abs(NORMAL.y);
    BINORMAL += vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
    BINORMAL = normalize(BINORMAL);
    
    uv_power_normal = pow(abs(NORMAL), vec3(triplanar_sharpness));
    uv_power_normal /= dot(uv_power_normal, vec3(1.0));
    uv_triplanar_pos = VERTEX * uv_scale + uv_offset;
    uv_triplanar_pos *= vec3(1.0, -1.0, 1.0);
}

void fragment() {
    // 1. Geometry (Normals)
    vec3 normal_tex = triplanar_texture(texture_normal, uv_power_normal, uv_triplanar_pos * normal_scale).rgb;
    NORMALMAP = normal_tex;
    NORMALMAP_DEPTH = normal_strength;
    
    // 2. Albedo (Base Color + Detail Add/Sub)
    // Sample only once for details
    vec4 detail_tex_raw = triplanar_texture(texture_albedo, uv_power_normal, uv_triplanar_pos * albedo_detail_scale);
    
    // Extract Green channel and apply contrast (Power)
    float detail_val = pow(detail_tex_raw.g, albedo_detail_power);
    
    // Add to base color (Strength can be negative to subtract)
    // We clamp to 0.0 to prevent negative colors if strength is very low
    ALBEDO = max(albedo.rgb + (vec3(detail_val) * albedo_detail_strength), vec3(0.0));
}

void light() {
    // 1. Angle of Light
    float NdotL = dot(NORMAL, LIGHT);
    
    // 2. Shadow Mask (Macro Shape)
    float transition_start = shadow_bias - shadow_softness;
    float transition_end = shadow_bias + shadow_softness;
    float shadow_mask = smoothstep(transition_start, transition_end, NdotL);
    
    // 3. Normal Detail Gradient (Micro Shading)
    float surface_shading = clamp(NdotL, 0.0, 1.0);
    
    // 4. Color Calculation
    vec3 shadow_layer = shadow_tint.rgb;
    
    // Lit Layer Blend (Flat vs Detailed)
    vec3 lit_layer_flat = lit_tint.rgb;
    vec3 lit_layer_detailed = lit_layer_flat * surface_shading;
    vec3 final_lit_layer = mix(lit_layer_detailed, lit_layer_flat, lit_normal_softness);

    // Combine Shadow and Lit
    vec3 base_lighting = mix(shadow_layer, final_lit_layer, shadow_mask);
    
    // 5. Rim Calculation
    float NdotV = dot(NORMAL, VIEW);
    float fresnel = pow(1.0 - clamp(NdotV, 0.0, 1.0), rim_width);
    
    // Mask rim by shadow
    float rim_mask = rim_on_shadow_only ? (1.0 - shadow_mask) : 1.0;
    vec3 rim_final = rim_color.rgb * fresnel * rim_power * rim_mask;
    
    // 6. Final Output
    vec3 final_color = (base_lighting + rim_final) * ATTENUATION;
    
    DIFFUSE_LIGHT += ALBEDO * final_color;
}