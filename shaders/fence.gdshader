shader_type spatial;
render_mode cull_disabled;
// Grilles et garde-corps : barreaux, poteaux et deux lisses ; entre les barreaux on voit
// à travers (des pixels jetés, pas de transparence alpha).
// UV = (distance le long de la grille, hauteur) ; UV2.y = hauteur totale.

#include "res://shaders/cutaway.gdshaderinc"

uniform float bar_spacing = 0.25;
uniform float bar_width = 0.07;
uniform float post_spacing = 2.5;
uniform float post_width = 0.1;
uniform float rail_height = 0.08;
uniform float cut_height = 2.4;
uniform float min_height = 0.25;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	bool bar = mod(UV.x, bar_spacing) < bar_width;
	bool post = mod(UV.x, post_spacing) < post_width;
	bool rail = UV.y < rail_height || UV.y > UV2.y - rail_height;
	if (!(bar || post || rail)
			|| cutaway(VERTEX, world_position.y, FRAGCOORD.xy, VIEW_MATRIX, cut_height, min_height)) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
