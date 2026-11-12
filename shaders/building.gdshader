shader_type spatial;
// Façades procédurales des bâtiments : étages, fenêtres (éclairées la nuit), toits unis.
// « Vision à travers les murs » : quand un bâtiment cache le joueur, un disque tramé
// s'ouvre autour de lui (pas de transparence alpha : on jette des pixels).

global uniform vec3 player_position;
global uniform float xray_radius;
global uniform float night_factor;

uniform vec3 window_dark : source_color = vec3(0.071, 0.102, 0.180);
uniform vec3 window_lit : source_color = vec3(0.957, 0.894, 0.757);
uniform vec2 window_cell = vec2(3.0, 2.8);
// Hauteur à laquelle sont arasés les bâtiments qui cachent les abords du joueur.
uniform float cut_height = 2.4;

varying vec3 world_position;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Ce qui se trouve entre la caméra et le joueur est découpé autour de lui :
	// tout près, on voit à travers ; un peu plus loin, les bâtiments sont arasés.
	vec3 player_view = (VIEW_MATRIX * vec4(player_position + vec3(0.0, 1.0, 0.0), 1.0)).xyz;
	if (VERTEX.z > player_view.z + 0.75) {
		ivec2 dither_cell = ivec2(FRAGCOORD.xy) % 4;
		float threshold = 0.9 + 0.1 * BAYER[dither_cell.x + dither_cell.y * 4] / 16.0;
		float distance_to_player = length(VERTEX.xy - player_view.xy);
		bool near = distance_to_player < xray_radius * 0.4 * threshold;
		bool above = world_position.y > cut_height && distance_to_player < xray_radius * threshold;
		if (near || above) {
			discard;
		}
	}

	// COLOR.a vaut 1 sur les murs et 0 sur les toits ; UV = (distance le long du mur, hauteur).
	float wall = COLOR.a;
	vec3 base = COLOR.rgb;
	vec2 cell = floor(UV / window_cell);
	vec2 in_cell = fract(UV / window_cell);
	float seed = UV2.x * 91.0;
	float window = step(0.25, in_cell.x) * step(in_cell.x, 0.75) * step(0.32, in_cell.y)
		* step(in_cell.y, 0.80);
	// Pas de fenêtre au rez-de-chaussée ni sur le dernier demi-étage (acrotère).
	window *= step(window_cell.y, UV.y) * step(UV.y, UV2.y - 0.6) * wall;
	float lit = step(1.0 - (0.04 + 0.5 * night_factor), hash(cell + seed)) * window;
	vec3 color = mix(base, window_dark, window);
	color = mix(color, window_lit, lit);
	// Nez de dalle : un filet sombre au bas de chaque étage.
	color = mix(color, base * 0.8, step(in_cell.y, 0.07) * wall * (1.0 - window));
	ALBEDO = color;
	EMISSION = window_lit * lit * night_factor;
	ROUGHNESS = 1.0;
}
