// Vue à travers le décor, partagée par les façades, les grilles et les objets : ce qui se
// trouve entre la caméra et Akan s'efface autour de lui (des pixels jetés, pas de
// transparence alpha). Les sols restent : seul ce qui dépasse `min_height` est découpé.

global uniform vec3 player_position;
global uniform float xray_radius;

const float CUTAWAY_BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

// Tout près d'Akan, on voit à travers ; un peu plus loin, ce qui dépasse `cut_height` est
// arasé. `view_vertex` est le fragment en repère de la caméra (VERTEX dans fragment()).
bool cutaway(vec3 view_vertex, float world_height, vec2 frag_coord, mat4 view_matrix,
		float cut_height, float min_height) {
	vec3 player_view = (view_matrix * vec4(player_position + vec3(0.0, 1.0, 0.0), 1.0)).xyz;
	if (view_vertex.z <= player_view.z + 0.75 || world_height <= min_height) {
		return false;
	}
	ivec2 cell = ivec2(frag_coord) % 4;
	float threshold = 0.9 + 0.1 * CUTAWAY_BAYER[cell.x + cell.y * 4] / 16.0;
	float distance_to_player = length(view_vertex.xy - player_view.xy);
	bool near = distance_to_player < xray_radius * 0.4 * threshold;
	bool above = world_height > cut_height && distance_to_player < xray_radius * threshold;
	return near || above;
}
