shader_type spatial;
// Façades procédurales des immeubles de Grigny 2 : panneaux de béton, fenêtres en grille
// (rideaux, volets roulants, éclairées la nuit), loggias ou balcons selon l'immeuble, linge
// qui sèche, paraboles, quelqu'un à sa fenêtre ; au rez-de-chaussée, soubassement et
// tags ; en haut, l'acrotère ; sur les toits, des gravillons.
// Les grandes tours ont leur dessin à elles, relevé sur place : de larges pilastres crème
// striés, des colonnes de fenêtres sombres, parfois un damier bordeaux et crème, des
// balcons empilés et une corniche blanche.
// « Vision à travers les murs » : quand un bâtiment cache le joueur, un disque tramé
// s'ouvre autour de lui (pas de transparence alpha : on jette des pixels).
//
// Données du maillage : COLOR.a vaut 1 sur les murs, 0 sur les toits, et 0,75 sur les
// murs de la gare (verrière éclairée, bardage rouge brique, casquette de métal) ;
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
const vec3 MAROON = vec3(0.486, 0.075, 0.125);
const vec3 CREAM = vec3(0.957, 0.894, 0.757);
const vec3 WHITE = vec3(0.933, 0.937, 0.941);
const vec3 FRAME = vec3(0.078, 0.082, 0.102);
// Une tour : à partir de cette hauteur ; une travée = un pilastre + une colonne de fenêtres.
const float TOWER_HEIGHT = 20.0;
const float BAY = 4.5;
const float PILASTER = 1.5;
const float CORNICE = 0.9;
const vec3 BRICK = vec3(0.71, 0.388, 0.122);
// La gare : un trumeau de bardage tous les tant de mètres, la verrière entre deux.
const float STATION_BAY = 9.0;
const float STATION_PIER = 2.2;
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

// La gare : bardage rouge brique à joints sombres, verrière à montants noirs toujours
// un peu éclairée (franchement le soir), casquette de métal en haut.
vec3 station_facade(vec2 uv, float height, out float lit) {
	lit = 0.0;
	if (uv.y > height - 0.6) {
		return WHITE * 0.9;
	}
	if (uv.y > height - 0.9) {
		return FRAME;
	}
	bool glass = mod(uv.x, STATION_BAY) > STATION_PIER && uv.y > 0.8;
	if (!glass) {
		bool joint = mod(uv.x, 1.2) < 0.06 || mod(uv.y, 1.0) < 0.06;
		return joint ? BRICK * 0.7 : BRICK;
	}
	if (mod(uv.x, 1.5) < 0.08 || mod(uv.y, 0.6) < 0.05) {
		return FRAME * 1.6;
	}
	lit = 0.6 + 0.4 * night_factor;
	return mix(window_dark, window_lit, lit);
}

// Une façade de tour : pilastre crème strié, puis une colonne de fenêtres à menuiseries
// noires ; l'allège est bordeaux et des panneaux crème se décalent d'un étage à l'autre
// dans le damier ; une travée sur six porte des balcons empilés.
vec3 tower_facade(vec2 uv, float seed, vec3 base, bool damier, out float lit) {
	lit = 0.0;
	float bay = floor(uv.x / BAY);
	float x = uv.x - bay * BAY;
	if (x < PILASTER) {
		float stria = step(0.8, fract(uv.x * 6.0));
		return CREAM * (0.93 - 0.06 * stria);
	}
	float storey = floor(uv.y / window_cell.y);
	float y = uv.y - storey * window_cell.y;
	float wx = x - PILASTER;
	vec2 cell = vec2(bay, storey);
	float roll = hash(cell + seed);
	float roll2 = hash(cell.yx + seed * 1.3 + 7.0);
	if (hash(vec2(bay, seed * 2.3)) < 0.17 && y < 1.1) {
		if (y < 0.18) {
			return WHITE * 0.95;
		}
		return (y < 0.26 || mod(wx, 0.3) < 0.05) ? FRAME : base * 0.5;
	}
	vec3 color;
	if (y < 0.85) {
		color = damier ? MAROON : base * 0.55;
	} else if (mod(wx, 1.0) < 0.07 || y > 2.62) {
		color = FRAME;
	} else {
		color = window_dark;
		lit = step(1.0 - (0.05 + 0.5 * night_factor), roll);
		if (roll2 < 0.25 && mod(wx, 1.0) > 0.55) {
			color = CURTAINS[int(roll2 * 12.0) % 3];
		}
		color = mix(color, window_lit, lit);
	}
	if (damier) {
		float shift = mod(storey + bay, 2.0) * 1.5;
		if (wx > shift + 0.08 && wx < shift + 1.42 && y > 0.45 && y < 2.35) {
			lit = 0.0;
			float grain = hash(floor(uv * 5.0) + seed);
			return CREAM * (0.86 + 0.06 * grain);
		}
	}
	return color;
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
	} else if (COLOR.a < 0.9) {
		color = station_facade(UV, height, lit);
	} else if (height >= TOWER_HEIGHT && hash(vec2(seed, 9.1)) < 0.85) {
		// Une tour de Grigny 2 : corniche blanche, soubassement, puis le dessin des travées.
		bool damier = hash(vec2(seed, 9.1)) < 0.45;
		if (UV.y > height - CORNICE) {
			color = UV.y > height - 0.15 ? WHITE : WHITE * 0.92;
		} else if (UV.y < window_cell.y * 0.35) {
			color = base * 0.78;
		} else {
			color = tower_facade(UV, seed, base, damier, lit);
		}
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
