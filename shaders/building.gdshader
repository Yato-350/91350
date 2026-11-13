shader_type spatial;
// Façades procédurales des immeubles de Grigny 2 : panneaux de béton, fenêtres en grille
// (rideaux, volets roulants, éclairées la nuit), loggias ou balcons selon l'immeuble, linge
// qui sèche, paraboles, quelqu'un à sa fenêtre ; au rez-de-chaussée, soubassement et
// tags ; en haut, l'acrotère ; sur les toits, des gravillons.
// « Vision à travers les murs » : quand un bâtiment cache le joueur, un disque tramé
// s'ouvre autour de lui (pas de transparence alpha : on jette des pixels).
//
// Données du maillage : COLOR.a vaut 1 sur les murs et 0 sur les toits ;
// UV = (distance le long du mur, hauteur) en mètres ; UV2 = (graine, hauteur du bâtiment).

#include "res://shaders/cutaway.gdshaderinc"

global uniform float night_factor;

uniform vec3 window_dark : source_color = vec3(0.071, 0.102, 0.180);
uniform vec3 window_lit : source_color = vec3(0.957, 0.894, 0.757);
uniform vec2 window_cell = vec2(3.0, 2.8);
// Hauteur à laquelle sont arasés les bâtiments qui cachent les abords du joueur.
uniform float cut_height = 2.4;

// Couleurs de la palette (sRGB) : linge, tags, détails.
const vec3 LAUNDRY[5] = vec3[5](
	vec3(1.0, 0.824, 0.247), vec3(1.0, 0.31, 0.545), vec3(0.435, 0.718, 1.0),
	vec3(0.933, 0.937, 0.941), vec3(0.784, 0.125, 0.173));
const vec3 TAGS[4] = vec3[4](
	vec3(1.0, 0.31, 0.545), vec3(0.557, 0.31, 0.851), vec3(0.494, 0.851, 0.341),
	vec3(0.098, 0.765, 0.941));
const vec3 CURTAINS[3] = vec3[3](
	vec3(0.957, 0.894, 0.757), vec3(0.365, 0.525, 0.776), vec3(1.0, 0.616, 0.227));
const vec3 SHUTTER = vec3(0.525, 0.541, 0.576);
const vec3 DISH = vec3(0.933, 0.937, 0.941);
const vec3 SKIN = vec3(0.627, 0.431, 0.298);
const vec3 SHIRT = vec3(0.169, 0.247, 0.4);

varying vec3 world_position;

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

bool in_box(vec2 point, vec2 low, vec2 high) {
	return point.x >= low.x && point.x < high.x && point.y >= low.y && point.y < high.y;
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

	vec3 base = COLOR.rgb;
	float seed = UV2.x * 91.0;
	float height = UV2.y;
	vec3 color = base;
	float lit = 0.0;

	if (COLOR.a < 0.5) {
		// Toit : gravillons, et une bordure plus claire.
		float grain = hash(floor(UV * 3.0) + seed);
		color = base * (0.9 + 0.12 * grain);
	} else {
		// Style de l'immeuble : loggias filantes, balcons, ou fenêtres simples.
		float style = hash(vec2(seed, 1.7));
		bool loggias = style < 0.35;
		bool balconies = style >= 0.35 && style < 0.65;
		float half_window = mix(0.55, 0.8, hash(vec2(seed, 3.1)));
		vec2 cell = floor(UV / window_cell);
		vec2 local = UV - cell * window_cell;
		float roll = hash(cell + seed);
		float roll2 = hash(cell.yx + seed * 1.3 + 7.0);
		bool ground_floor = UV.y < window_cell.y;
		bool parapet = UV.y > height - 0.6;
		vec2 window_low = vec2(window_cell.x * 0.5 - half_window, 0.95);
		vec2 window_high = vec2(window_cell.x * 0.5 + half_window, 2.25);

		// Joints entre les panneaux de façade, nez de dalle à chaque étage.
		if (mod(UV.x, 1.5) < 0.06) {
			color = base * 0.92;
		}
		if (local.y < 0.12) {
			color = base * 0.8;
		}

		if (parapet) {
			color = UV.y > height - 0.1 ? base * 1.08 : base * 0.88;
		} else if (ground_floor) {
			// Soubassement sali, et des tags sur un pan de mur sur trois environ.
			if (UV.y < 0.4) {
				color = base * 0.78;
			}
			float panel = floor(UV.x / 3.5);
			if (hash(vec2(panel, seed * 0.7)) < 0.35 && UV.y > 0.5 && UV.y < 2.0) {
				// Chaque tag a son écriture : fréquence, penchant et ondulation tirés au sort,
				// et un liseré sombre autour des lettres.
				vec2 tag = vec2(mod(UV.x, 3.5), UV.y);
				float frequency = mix(1.1, 2.4, hash(vec2(panel, seed * 2.1)));
				float slant = mix(-0.6, 0.6, hash(vec2(panel, seed * 3.7)));
				float wave = mix(0.15, 0.6, hash(vec2(panel, seed * 5.3)));
				float blob = length((tag - vec2(1.75, 1.25)) / vec2(1.45, 0.55));
				float letters = fract(tag.x * frequency + tag.y * slant + sin(tag.y * 6.0 + panel) * wave);
				float stroke = abs(letters - 0.5);
				if (blob < 1.0 && stroke < 0.13) {
					color = TAGS[int(hash(vec2(panel, seed)) * 4.0)];
				} else if (blob < 1.08 && stroke < 0.21) {
					color = base * 0.35;
				}
			}
		} else {
			bool in_window = in_box(local, window_low, window_high);
			if (in_window) {
				color = window_dark;
				lit = step(1.0 - (0.04 + 0.5 * night_factor), roll);
				float across = (local.x - window_low.x) / (window_high.x - window_low.x);
				float down = (window_high.y - local.y) / (window_high.y - window_low.y);
				if (roll2 > 0.82) {
					// Volet roulant plus ou moins baissé.
					if (down < fract(roll2 * 7.0) + 0.2) {
						color = mod(local.y, 0.18) < 0.06 ? SHUTTER * 0.85 : SHUTTER;
						lit = 0.0;
					}
				} else if (roll2 < 0.3 && (across < 0.3 || across > 0.7)) {
					color = CURTAINS[int(roll2 * 10.0) % 3];
				}
				// Quelqu'un à sa fenêtre, de jour.
				if (roll < 0.035 && night_factor < 0.5) {
					vec2 head = vec2(window_cell.x * 0.5, 1.75);
					if (length(local - head) < 0.16) {
						color = SKIN;
					} else if (in_box(local, vec2(head.x - 0.3, 0.95), vec2(head.x + 0.3, 1.55))) {
						color = SHIRT;
					}
				}
				color = mix(color, window_lit, lit);
			} else {
				// Parabole accrochée près d'une fenêtre sur cinq environ.
				vec2 dish_center = vec2(window_high.x + 0.3, 2.0);
				if (roll > 0.2 && roll < 0.38 && length(local - dish_center) < 0.24) {
					color = length(local - dish_center) < 0.07 ? DISH * 0.7 : DISH;
				}
			}
			// Balcon ou loggia : un garde-corps devant le bas de la fenêtre, une ombre dessous.
			float rail_low = 0.15;
			float rail_high = 1.0;
			bool rail = false;
			if (loggias) {
				rail = local.y >= rail_low && local.y < rail_high;
			} else if (balconies) {
				rail = local.y >= rail_low && local.y < rail_high
					&& local.x > window_low.x - 0.25 && local.x < window_high.x + 0.25;
			}
			if (rail) {
				color = local.y < rail_low + 0.08 ? base * 0.62 : base * 1.06;
				if (local.y > rail_high - 0.06) {
					color = base * 0.9;
				}
				// Le linge qui sèche, sur un balcon sur huit environ.
				if (roll2 > 0.3 && roll2 < 0.42) {
					float slot = floor((local.x - window_low.x) / 0.36);
					float in_slot = mod(local.x - window_low.x, 0.36);
					float drop = 0.35 + 0.2 * hash(vec2(slot, roll2));
					if (slot >= 0.0 && slot < 4.0 && in_slot < 0.28 && local.y > rail_high - drop) {
						color = LAUNDRY[int(hash(vec2(slot, roll)) * 5.0)];
					}
				}
			}
		}
	}

	ALBEDO = color;
	EMISSION = window_lit * lit * night_factor;
	ROUGHNESS = 1.0;
}
