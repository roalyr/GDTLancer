shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,

	// Blending and culling.
	blend_mix,
	cull_front,

	unshaded,
	diffuse_lambert,
	specular_disabled,

	// Additional flags just in case.
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
uniform vec4 albedo_far : hint_color;

uniform float fade_distance = 1e5;
uniform float fade_distance_far = 3e5;
uniform float fade_power = 2.0;

uniform float rim_exponent = 0.5;

// Non-linear perspective
uniform float scale_start = 100000;
uniform float scale_end_mul = 100;
uniform float scale_power = 1.0;
uniform float scale_min = 0.5;

const float pi = 3.1415926535;

void vertex() {
	// --- Non-linear perspective (based on distance) ---
	float distance_vert = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	float scale_factor = pow(clamp((scale_end_mul*scale_start - distance_vert) / (scale_end_mul*scale_start - scale_start), scale_min, 1.0), scale_power);
	VERTEX *= scale_factor;
}


void fragment()
{
	//float dt = clamp(abs(dot(NORMAL, VIEW)), 1e-6, 1.0);
	//float rim = clamp(pow(dt,rim_exponent), 1e-6, 1.0);
	
	float luminosity = dot(COLOR.rgb, vec3(lum_weight_r, lum_weight_g, lum_weight_b));
	luminosity = max(luminosity, 0.0);

	// Now use this calculated luminosity value in your original formula
	float vertex_mask = vertex_mask_overlay + pow(luminosity, vertex_mask_power);
	if (vertex_mask < 0.01) {
		discard;
	}
	
	ALBEDO = albedo_strength * albedo.rgb * COLOR.rgb;
	
	// Apply vertex mask
	ALBEDO *= vertex_mask;
	
	// color tweak.
	ALBEDO = vec3(
		pow(ALBEDO.r, color_power_r)*color_multiplier_r,
		pow(ALBEDO.g, color_power_g)*color_multiplier_g,
		pow(ALBEDO.b, color_power_b)*color_multiplier_b
	);

	// Overlay dark parts
	ALBEDO += (1.0 - clamp(vertex_mask, 0.0, 1.0)) * albedo_ambient.rgb;
	
	// Replace near parts with ambient color to hide polygons.
	float dist = length(VERTEX);
	float fade = pow(clamp(smoothstep(0.0, fade_distance, dist), 1e-6, 1.0), fade_power); // fades in
	float fade_far = pow(clamp(smoothstep(0.0, fade_distance_far, dist), 1e-6, 1.0), fade_power); // fades out
	vec3 current = ALBEDO;
	ALBEDO = (1.0-fade) * (albedo_near.rgb * vertex_mask) // Near fade in color
		+ (1.0-fade) * (albedo_ambient.rgb * (1.0 - vertex_mask)) // Adjusted by mask
		+ fade * (1.0-fade_far) * current // Mesh color between fade in and fade out
		+ (fade_far) * (albedo_ambient.rgb) // Adjusted by mask
		;
}