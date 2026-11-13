shader_type spatial;
// Façades procédurales des bâtiments : étages, fenêtres (éclairées la nuit), toits unis.
// « Vision à travers les murs » : quand un bâtiment cache le joueur, un disque tramé
// s'ouvre autour de lui (pas de transparence alpha : on jette des pixels).

#include "res://shaders/cutaway.gdshaderinc"

global uniform float night_factor;

uniform vec3 window_dark : source_color = vec3(0.071, 0.102, 0.180);
uniform vec3 window_lit : source_color = vec3(0.957, 0.894, 0.757);
uniform vec2 window_cell = vec2(3.0, 2.8);
// Hauteur à laquelle sont arasés les bâtiments qui cachent les abords du joueur.
uniform float cut_height = 2.4;

varying vec3 world_position;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Ce qui se trouve entre la caméra et le joueur est découpé autour de lui :
	// tout près, on voit à travers ; un peu plus loin, les bâtiments sont arasés.
	if (cutaway(VERTEX, world_position.y, FRAGCOORD.xy, VIEW_MATRIX, cut_height, -1.0)) {
		discard;
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
