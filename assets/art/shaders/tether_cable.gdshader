// Harpoon cable ribbon (Tether / TetherRope). Vertex colour red carries the strain, 0 slack .. 1
// full: a loose cable is dull metal, a strained one brightens toward a hot steel sheen.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 slack_color : hint_color = vec4(0.42, 0.42, 0.46, 1.0);
uniform vec4 strained_color : hint_color = vec4(0.95, 0.9, 0.78, 1.0);
uniform float strain_curve = 1.5; // >1: the sheen comes on late, near full strain

void fragment() {
	float strain = pow(clamp(COLOR.r, 0.0, 1.0), strain_curve);
	ALBEDO = mix(slack_color.rgb, strained_color.rgb, strain);
}
