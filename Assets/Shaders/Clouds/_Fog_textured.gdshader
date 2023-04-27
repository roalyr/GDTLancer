shader_type spatial;

render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_add,
	cull_disabled,
	
	//unshaded,
	diffuse_lambert, 
	specular_disabled,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 albedo : hint_color;

uniform float density;
uniform float scale;
uniform float power;
uniform float rim_strength = 0.05;
uniform float rim_exponent : hint_range(0.0, 50.0, 0.1) = 15.0;
uniform float alpha_clip : hint_range(0,1) = 1.0;

uniform sampler2D noise_texture;

void fragment() {
	// Get the world position of the fragment
    vec3 camera_pos = (CAMERA_MATRIX * vec4(VERTEX, 1.0)).xyz ;
	float noise_value = 
		 texture(noise_texture, (camera_pos.xy + camera_pos.z)/ scale ).r 
		// *texture(noise_texture, (camera_pos.yz + camera_pos.x)/ scale ).r 
		// *texture(noise_texture, (camera_pos.zx + camera_pos.y)/ scale ).r 
	;


	float dt = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = clamp(pow(dt, rim_exponent)*rim_strength, 1e-6, alpha_clip);

    float alpha = pow(noise_value, power) * density * rim;
    ALBEDO = albedo.rgb*vec3(alpha);
	ALPHA = alpha;
}
