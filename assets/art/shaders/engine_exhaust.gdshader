// Engine exhaust (from the legacy project): additive, unshaded glow on the exhaust cone models
// (assets/models/fx). Vertex colour red shapes the glow along the cone (bright at the nozzle,
// fading out); `power` sharpens that falloff. The cone pulses lengthwise. `intensity` follows
// the engine's thrust (EngineExhaust), so an idle engine barely glows.
shader_type spatial;
render_mode vertex_lighting, blend_add, cull_disabled, unshaded, specular_disabled, ambient_light_disabled, depth_draw_opaque;

uniform vec4 albedo : hint_color;
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.05;
uniform float pulse_frequency = 50.0;
uniform float power = 1.0;
uniform float intensity = 1.0;

void vertex() {
	float a = (cos(TIME * pulse_frequency) + 1.0) * 0.5;
	VERTEX.y = VERTEX.y * (a * pulse_amount + (1.0 - pulse_amount));
}

void fragment() {
	ALBEDO = albedo.rgb * pow(COLOR.r, power) * intensity;
}
