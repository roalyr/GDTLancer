shader_type spatial;
render_mode
	// Vertex or pixel shading (screen-large object can use vertex)
	vertex_lighting,
	
	// Blending and culling.
	blend_add,
	cull_front,
	
	unshaded,
	//diffuse_lambert, 
	//specular_schlick_ggx,
	
	// Additional flags just in case.
	ambient_light_disabled,
	depth_draw_opaque;

uniform vec4 halo_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 corona_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);
uniform vec4 core_color : hint_color = vec4(1.0, 0.9, 0.4, 1.0);

uniform float halo_strength = 0.2;
uniform float halo_power = 1.0;
uniform float halo_amount = 1.0;

uniform float corona_strength = 10.0;
uniform float corona_power = 10.0;
uniform float corona_amount = 1.0;

uniform float core_strength = 50.0;
uniform float core_power = 50.0;
uniform float core_amount = 50.0;

uniform sampler2D displacement_texture;
uniform float displacement_scale = 0.02;
uniform float displacement_velocity = 0.01;

void vertex() {
	vec2 tex_position_x = VERTEX.yz / 1.0 - TIME*displacement_velocity;
	vec2 tex_position_y = VERTEX.xz / 1.0 + TIME*displacement_velocity;
	vec2 tex_position_z = VERTEX.xy / 1.0 - TIME*displacement_velocity;
	
	float displacement_x = 2.0*texture(displacement_texture, tex_position_x).r-1.0;
	float displacement_y = 2.0*texture(displacement_texture, tex_position_y).r-1.0;
	float displacement_z = 2.0*texture(displacement_texture, tex_position_z).r-1.0;
	
	VERTEX.z += displacement_z * displacement_scale;
	VERTEX.x += displacement_x * displacement_scale;
	VERTEX.y += displacement_y * displacement_scale;
}

void fragment()
{
	float halo = clamp(pow(dot(NORMAL,VIEW), halo_power)*halo_strength, 0.0, 1.0);
	float corona = clamp(pow(dot(NORMAL,VIEW), corona_power)*corona_strength, 0.0, 1.0);
	float core = clamp(pow(dot(NORMAL,VIEW), core_power)*core_strength, 0.0, 1.0);
	
	ALBEDO = 
		halo*halo_amount*halo_color.rgb 
		+ corona*corona_amount*corona_color.rgb 
		+ core*core_amount*core_color.rgb;
		
	ALPHA = halo;
}
