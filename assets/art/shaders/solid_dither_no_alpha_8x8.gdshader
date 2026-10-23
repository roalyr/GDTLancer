shader_type spatial;

render_mode
    blend_mix,
    cull_back,
    diffuse_lambert,
    specular_phong,
    depth_draw_opaque;

// --- Base colors per Fresnel layer ---
uniform vec4 albedo : hint_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform vec4 albedo_specular : hint_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 albedo_gloss : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 emission : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 500.0, 0.1) = 1.0;

// --- Fresnel exponents (how tight each rim layer is) ---
// albedo_exponent = 0 means flat fill; higher = more edge-concentrated
uniform float albedo_exponent : hint_range(0.0, 50.0, 0.1) = 0.0;
uniform float specular_exponent : hint_range(0.0, 100.0, 0.1) = 5.0;
uniform float gloss_exponent : hint_range(0.0, 500.0, 0.1) = 50.0;
uniform float roughness_exponent : hint_range(0.0, 10.0, 0.1) = 3.0;
uniform float roughness_sharpness : hint_range(0.0, 100.0, 0.1) = 10.0;


uniform float roughness : hint_range(0.0, 1.0) = 1.0;

// --- Rim lighting (in light()) ---
uniform float rim_strength = 1.0;
uniform float rim_exponent = 3.0;
uniform float rim_intensity = 0.3;


// --- Fade (LOD discard) ---
uniform float fade_start = 300000.0;
uniform float fade_end_mul = 5.0;
uniform float fade_power = 2.0;


// --- Accumulated damage (triplanar, in the model's own space) ---
// Patches of damage_texture spread over the hull as `damage` (0..1: hull lost, set per ship by
// HullWear) rises: they cover the plating where damage_noise lies below damage * damage_coverage,
// with dithered edges, and darken more the more hull is lost. Undamaged hulls skip the sampling.
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D damage_texture : hint_albedo;  // Multiplies the hull colour inside the patches
uniform sampler2D damage_noise : hint_black;  // Where patches start (dark first) and how they spread
uniform vec4 damage_color : hint_color = vec4(0.45, 0.4, 0.37, 1.0);  // Soot tint inside the patches
uniform float damage_texture_scale = 0.125;  // Repeats per model unit (m)
uniform float damage_noise_scale = 0.04;
uniform float damage_noise_contrast : hint_range(0.5, 5.0) = 2.0;  // Spreads a flat noise texture over 0..1
uniform float damage_coverage : hint_range(0.0, 1.0) = 0.85;  // Share of the noise covered at no hull left
uniform float damage_edge : hint_range(0.0, 0.5) = 0.08;  // Width of the dithered patch edge (noise units)
uniform float damage_min_strength : hint_range(0.0, 1.0) = 0.4;  // Patch strength when first damaged; 1 at no hull left
uniform float damage_blend_sharpness = 4.0;  // Higher: sharper seams between the three projections

varying vec3 damage_pos;
varying vec3 damage_normal;


// --- Dither and posterization constants ---
const float light_dither_strength = 0.900;
const float posterization_levels = 6.0;
const float dither_pixel_size = 2.0;


// --- Non-linear perspective ---
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;


// --- Helper Functions ---


float bayer2x2(vec2 p) {
    return p.x * 2.0 + p.y * (3.0 - 4.0 * p.x);
}

float bayer8x8(vec2 screen_pos) {
    vec2 p = mod(floor(screen_pos), 8.0);
    vec2 p0 = mod(p, 2.0);
    vec2 p1 = mod(floor(p / 2.0), 2.0);
    vec2 p2 = floor(p / 4.0);
    float val = 16.0 * bayer2x2(p0) + 4.0 * bayer2x2(p1) + bayer2x2(p2);
    return val / 64.0;
}

// A texture projected along the three axes, blended by `weights` (sum 1).
vec4 triplanar(sampler2D tex, vec3 pos, vec3 weights) {
    return texture(tex, pos.zy) * weights.x + texture(tex, pos.xz) * weights.y + texture(tex, pos.xy) * weights.z;
}

// --- Vertex Function ---
void vertex() {
    // Model space, before the non-linear scaling: damage patches stay put on the hull, the same on every LOD
    damage_pos = VERTEX;
    damage_normal = NORMAL;

    // Non-linear perspective
    float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
    float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
    VERTEX *= scale_factor;

    // TBN for triplanar
    TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.y);
    TANGENT += vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
    TANGENT = normalize(TANGENT);
    BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x);
    BINORMAL += vec3(0.0, 0.0, -1.0) * abs(NORMAL.y);
    BINORMAL += vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
    BINORMAL = normalize(BINORMAL);

}

// --- Fragment Function ---
void fragment() {
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);

    // --- Distance-based LOD discard dithering ---
    float distance_vert = length(VERTEX);
    float fade_range = fade_end_mul * fade_start - fade_start;
    if (fade_range > 0.0 && distance_vert > fade_start) {
        float fade_factor = pow(clamp((fade_end_mul * fade_start - distance_vert) / fade_range, 0.0, 1.0), fade_power);
        float bayer_val = bayer8x8(dither_pos);
        if (fade_factor < bayer_val + 1e-6) {
            discard;
        }
    }

    // --- Fresnel (dot(NORMAL, VIEW)) ---
    // 1.0 = face-on, 0.0 = grazing edge.
    // albedo_exponent=0 → flat fill; higher → concentrates color toward edges.
    float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float albedo_rim    = clamp(pow(dt, max(albedo_exponent,    0.001)), 0.0, 1.0);
    float specular_rim  = clamp(pow(dt, max(specular_exponent,  0.001)), 0.0, 1.0);
    float gloss_rim     = clamp(pow(dt, max(gloss_exponent,     0.001)), 0.0, 1.0);
    float roughness_rim = clamp(pow(dt, max(roughness_exponent, 0.001)), 0.0, 1.0);


    // --- Multi-layer Fresnel color composition ---
    // Three additive layers: base fill, mid specular, tight gloss highlight.
    // Each uses its own color × Fresnel mask × texture sample.
    ALBEDO = albedo.rgb;
	//        * albedo_rim 
     //      + albedo_specular.rgb * specular_rim 
      //     + albedo_gloss.rgb    * gloss_rim    ;
    ALBEDO *= COLOR.rgb;

    // --- Accumulated damage ---
    if (damage > 0.0) {
        vec3 weights = pow(abs(normalize(damage_normal)), vec3(damage_blend_sharpness));
        weights /= max(weights.x + weights.y + weights.z, 0.0001);
        float spread = triplanar(damage_noise, damage_pos * damage_noise_scale, weights).r;
        spread = clamp((spread - 0.5) * damage_noise_contrast + 0.5, 0.0, 1.0);
        float cover = damage * damage_coverage;
        float inside = clamp((cover - spread) / max(damage_edge, 0.0001) + 0.5, 0.0, 1.0);
        if (inside > bayer8x8(dither_pos)) {
            vec3 scorch = triplanar(damage_texture, damage_pos * damage_texture_scale, weights).rgb * damage_color.rgb;
            ALBEDO *= mix(vec3(1.0), scorch, mix(damage_min_strength, 1.0, damage));
        }
    }

    // Fresnel-modulated roughness: smooth at grazing edges, rough face-on
    ROUGHNESS = 1.0 - roughness * pow(1.0 - roughness_rim, roughness_sharpness);

    EMISSION = emission.rgb * COLOR.rgb * emission_strength;
}

// --- Light Function ---
void light() {
    vec2 dither_pos = FRAGCOORD.xy / max(1.0, dither_pixel_size);
    float threshold = bayer8x8(dither_pos);

    // Standard Lambertian intensity
    float NoL = max(0.0, dot(NORMAL, LIGHT));

    // Dithered + posterized Lambert
    float levels = max(1.0, posterization_levels);
    float step_size = 1.0 / levels;
    float dither_offset = (threshold - 0.5) * step_size * light_dither_strength;
    float dithered_NoL = clamp(NoL + dither_offset, 0.0, 1.0);
    float quantized_NoL = floor(dithered_NoL * levels) / levels;

    // Fresnel rim highlight in the light pass
    float fresnel = 1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
    float rim = pow(fresnel, rim_exponent) * rim_strength * rim_intensity;

    DIFFUSE_LIGHT += ALBEDO * (quantized_NoL + rim * quantized_NoL) * ATTENUATION * LIGHT_COLOR;
    SPECULAR_LIGHT += vec3(0.0);
}