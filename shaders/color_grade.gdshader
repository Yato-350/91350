shader_type canvas_item;
// Dernière passe du rendu : saturation (gris du régime → couleur), léger tramage,
// puis remplacement de chaque pixel par la couleur de palette la plus proche.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform vec3 palette[32];
// 0 = pas de palette : l'image passe telle quelle.
uniform int palette_size = 0;
uniform float saturation = 1.0;
uniform float dither_strength = 0.04;

// Matrice de Bayer 4×4 : un motif régulier qui mélange deux couleurs voisines.
const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, saturation);
	if (palette_size > 0) {
		ivec2 cell = ivec2(FRAGCOORD.xy) % 4;
		color += (BAYER[cell.x + cell.y * 4] / 16.0 - 0.5) * dither_strength;
		float best = 1000.0;
		vec3 nearest = color;
		for (int i = 0; i < palette_size; i++) {
			vec3 delta = color - palette[i];
			float distance_squared = dot(delta, delta);
			if (distance_squared < best) {
				best = distance_squared;
				nearest = palette[i];
			}
		}
		color = nearest;
	}
	COLOR = vec4(color, 1.0);
}
