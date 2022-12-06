shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_add,
	cull_back,
	
	unshaded,
	//diffuse_lambert, 
	//specular_schlick_ggx,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;
	
uniform vec4 albedo : hint_color;
uniform float scale = 0.1;
uniform float intensity = 1.0;
uniform float power = 5.0;
uniform float pulse_factor : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_rate = 15.0;
uniform float phase : hint_range(0.0, 3.14) = 0.0;

void vertex() {
	MODELVIEW_MATRIX = INV_CAMERA_MATRIX * mat4(CAMERA_MATRIX[0],CAMERA_MATRIX[1],CAMERA_MATRIX[2],WORLD_MATRIX[3]);
	if (PROJECTION_MATRIX[3][3] != 0.0) {
		float h = abs(1.0 / (2.0 * PROJECTION_MATRIX[1][1]));
		float sc = (h * 2.0)*scale; //consistent with Y-fov
		MODELVIEW_MATRIX[0]*=sc;
		MODELVIEW_MATRIX[1]*=sc;
		MODELVIEW_MATRIX[2]*=sc;
	} else {
		float sc = -(MODELVIEW_MATRIX)[3].z*scale;
		MODELVIEW_MATRIX[0]*=sc;
		MODELVIEW_MATRIX[1]*=sc;
		MODELVIEW_MATRIX[2]*=sc;
	}
}

void fragment() {
	float pulse = (1.0 * pulse_factor - sin(TIME * pulse_rate + phase) * (1.0 - pulse_factor));
	ALBEDO = albedo.rgb 
	* pow(COLOR.r, power / pulse) 
	* intensity 
	* pulse;
}
