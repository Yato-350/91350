class_name ZoneDressing
## Habillage d'une zone extérieure, ajouté à la cuisson : trottoirs, marquages au sol,
## parkings et voitures garées, arbres, lampadaires, mobilier urbain, entrées des
## immeubles, clôtures et haies, pylônes à haute tension (sans leurs câbles : à 30 m de
## haut, ils barreraient tout l'écran).
##
## Tout est placé de façon déterministe : une même zone donne toujours le même habillage.
## Les objets répétés sont dessinés en MultiMesh (PropInstances : un par modèle et par
## carré de 64 m),
## leurs collisions fusionnées en une forme par carré, et les cases de navigation qu'ils
## occupent sont bouchées.

const MATERIAL := preload("res://assets/materials/prop.tres")
const FENCE_MATERIAL := preload("res://assets/materials/fence.tres")
const CHUNK_SIZE := 64.0
const PROP_FOLDER := "props/"
const SEED_SALT := 91350

## Rues sans trottoirs ni lampadaires : chemins, dessertes de parking, voies de bus.
const NO_SIDEWALK: Array[String] = [
	"footway", "path", "steps", "cycleway", "pedestrian", "track", "service", "busway"
]
const SIDEWALK_WIDTH := 2.0
const SIDEWALK_Y := 0.035
const SIDEWALK_COLOR := "beton_4"
const MARKING_Y := 0.06
const MARKING_COLOR := "blanc"
const DASH_LENGTH := 3.0
const DASH_GAP := 3.0
const DASH_WIDTH := 0.15
const DASHED_MIN_WIDTH := 6.5
const ZEBRA_STRIPE := 0.5
const ZEBRA_LENGTH := 2.5
const ZEBRA_Y := 0.062
const DEFAULT_ROAD_WIDTH := 6.5

const PARKING_Y := 0.045
const PARKING_COLOR := "beton_2"
const STALL_WIDTH := 2.5
const STALL_DEPTH := 5.0
const AISLE_WIDTH := 6.0
const STALL_LINE_WIDTH := 0.1
const STALL_MARGIN := 0.5
const CAR_RATE := 0.6
const CAR_MODELS: Array[String] = [
	"voiture", "voiture_blanche", "voiture_bleue", "voiture_rouge", "voiture_brune"
]

## Essences tirées au hasard (le feuillu deux fois plus souvent).
const TREE_MODELS: Array[String] = ["arbre_feuillu", "arbre_feuillu", "arbre_haut", "pin"]
const BUSH_MODEL := "buisson"
## Arbres semés dans les espaces verts : type → [pas de la grille (m), probabilité].
const TREE_SCATTER := {
	"park": [9.0, 0.55],
	"garden": [9.0, 0.4],
	"grass": [13.0, 0.3],
	"village_green": [12.0, 0.3],
	"recreation_ground": [12.0, 0.25],
	"meadow": [14.0, 0.15],
	"cemetery": [10.0, 0.3],
	"forest": [6.0, 0.85],
	"wood": [6.0, 0.85],
	"scrub": [8.0, 0.4],
}
## Probabilité, en plus de celle de l'arbre, de semer un buisson.
const BUSH_RATE := 0.2
const TREE_SPACING := 4.0
## Les arbres semés restent à cette distance du bord des trottoirs.
const TREE_ROAD_MARGIN := 1.5
const TREE_SCALE_RANGE := Vector2(0.85, 1.2)
const TRUNK_SIZE := Vector3(0.5, 2.4, 0.5)
const BUSH_SIZE := Vector3(1.2, 0.9, 1.2)
## Demi-diagonale d'une case : la distance d'un point au centre de sa case.
const CELL_REACH := 0.71

const LAMP_MODEL := "lampadaire"
const LAMP_SPACING := 30.0
const LAMP_SIDE_OFFSET := 1.0
const LAMP_MIN_GAP := 12.0
## La lanterne et le mât, dans le repère du lampadaire (la crosse pointe vers -Z).
const LAMP_HEAD := Vector3(0.06, 5.3, -0.25)
const LAMP_POLE := Vector3(0.06, 2.9, 0.19)
const POLE_SIZE := Vector3(0.2, 5.8, 0.2)

const FURNITURE_MODELS := {
	"banc": "banc",
	"poubelle": "poubelle",
	"abribus": "abribus",
	"ecran": "ecran_propagande",
	"camera": "camera",
	"pylone": "pylone",
	"conteneurs": "conteneurs",
	"plot": "plot",
}
const FURNITURE_SCALE := {"ecran": 1.6}
## Hauteur de la collision d'un pylône : on bute sur ses pieds, pas sur ses consoles.
const PYLON_COLLISION_HEIGHT := 3.0

const ENTRANCE_MODEL := "entree_immeuble"
## Moitié de l'épaisseur du modèle d'entrée : son dos touche la façade.
const ENTRANCE_DEPTH := 0.25

## Clôtures : hauteur, épaisseur et couleurs (côtés, dessus).
const BARRIERS := {
	"fence": {"height": 1.1, "width": 0.08, "color": "beton_2"},
	"guard_rail": {"height": 0.7, "width": 0.15, "color": "beton_5"},
	"hedge": {"height": 1.2, "width": 0.9, "color": "vert_sombre", "top": "vert_feuille"},
	"wall": {"height": 1.6, "width": 0.3, "color": "beton_4", "top": "beton_5"},
	"retaining_wall": {"height": 1.0, "width": 0.4, "color": "beton_3", "top": "beton_4"},
}
## Une grille est ajourée (shader) ; les autres clôtures sont pleines.
const SEE_THROUGH: Array[String] = ["fence", "guard_rail"]
const GATE_GAP := 1.6
## Une clôture arrête Akan même si elle est plus basse ou plus fine que cela.
const BARRIER_MIN_COLLISION := Vector2(0.1, 1.2)
## Les cases dont le centre est à moins de cette distance d'une clôture sont bouchées.
const BARRIER_NAV_REACH := 0.5


static func dress(geometry: ZoneGeometry, zone: Dictionary, palette: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Dressing"
	geometry.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(zone.get("zone", ""))) + SEED_SALT
	var placer := Placer.new(geometry)
	var roads: Array = zone.get("roads", [])
	_add_sidewalks(root, roads, palette)
	var markings := SurfaceTool.new()
	markings.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_road_markings(markings, roads, zone.get("crossings", []), palette)
	var road_mask := _road_mask(geometry.nav_data, roads)
	var parkings := _polygons(zone.get("parkings", []))
	_add_parkings(root, markings, placer, parkings, road_mask, rng, palette)
	MeshKit.commit(root, "Markings", markings, MATERIAL)
	_add_entrances(geometry, placer, zone.get("entrances", []))
	_add_barriers(root, placer, zone.get("barriers", []), zone.get("gates", []), palette)
	_add_furniture(placer, zone.get("furniture", []), zone.get("power_lines", []))
	_add_trees(placer, zone, road_mask, parkings, rng)
	_add_lamps(geometry, placer, roads)
	placer.commit(root)


## Les douze triangles d'une boîte (centre, taille, orientation), pour une collision.
static func box_faces(center: Vector3, size: Vector3, basis: Basis) -> PackedVector3Array:
	var half := size / 2.0
	var corners: Array[Vector3] = []
	for index: int in 8:
		var local := Vector3(
			half.x if (index & 1) != 0 else -half.x,
			half.y if (index & 2) != 0 else -half.y,
			half.z if (index & 4) != 0 else -half.z
		)
		corners.append(center + basis * local)
	var faces := PackedVector3Array()
	for quad: Array in [
		[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]
	]:
		for corner: int in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
			faces.append(corners[corner])
	return faces


# --- Rues ------------------------------------------------------------------


static func _add_sidewalks(root: Node3D, roads: Array, palette: Dictionary) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for road: Dictionary in roads:
		if road["kind"] in NO_SIDEWALK:
			continue
		var width: float = road["width"] + SIDEWALK_WIDTH * 2.0
		MeshKit.add_ribbon(
			surface, _points(road["points"]), width, SIDEWALK_Y, palette[SIDEWALK_COLOR]
		)
	MeshKit.commit(root, "Sidewalks", surface, MATERIAL)


static func _add_road_markings(
	surface: SurfaceTool, roads: Array, crossings: Array, palette: Dictionary
) -> void:
	var color: Color = palette[MARKING_COLOR]
	for road: Dictionary in roads:
		if road["kind"] in NO_SIDEWALK or road["width"] < DASHED_MIN_WIDTH:
			continue
		var points := _points(road["points"])
		# Le motif (trait, vide) continue d'un tronçon à l'autre.
		var phase := 0.0
		for index: int in points.size() - 1:
			var start := points[index]
			var length := start.distance_to(points[index + 1])
			if length <= 0.0:
				continue
			var direction := (points[index + 1] - start) / length
			var along := phase
			while along < length:
				var dash_end := minf(along + DASH_LENGTH, length)
				var dash := PackedVector2Array(
					[start + direction * along, start + direction * dash_end]
				)
				MeshKit.add_ribbon(surface, dash, DASH_WIDTH, MARKING_Y, color)
				along += DASH_LENGTH + DASH_GAP
			phase = along - length
	# Passages piétons : des bandes dans l'axe de la rue, côte à côte sur toute sa largeur.
	for crossing: Dictionary in crossings:
		var at := Vector2(crossing["x"], crossing["z"])
		var angle: float = crossing["angle"]
		var direction := Vector2(cos(angle), sin(angle))
		var across := Vector2(-direction.y, direction.x)
		var half_width := _road_width_at(roads, at) / 2.0
		var offset := -half_width + ZEBRA_STRIPE
		while offset <= half_width - ZEBRA_STRIPE:
			var center := at + across * offset
			var stripe := PackedVector2Array(
				[center - direction * ZEBRA_LENGTH / 2.0, center + direction * ZEBRA_LENGTH / 2.0]
			)
			MeshKit.add_ribbon(surface, stripe, ZEBRA_STRIPE, ZEBRA_Y, color)
			offset += ZEBRA_STRIPE * 2.0


# Largeur de la rue carrossable la plus proche du point.
static func _road_width_at(roads: Array, at: Vector2) -> float:
	var best := INF
	var width := DEFAULT_ROAD_WIDTH
	for road: Dictionary in roads:
		if road["kind"] in NO_SIDEWALK:
			continue
		var points := _points(road["points"])
		for index: int in points.size() - 1:
			var foot := Geometry2D.get_closest_point_to_segment(
				at, points[index], points[index + 1]
			)
			if foot.distance_to(at) < best:
				best = foot.distance_to(at)
				width = road["width"]
	return width


# Cases couvertes par les rues et leurs trottoirs, marge comprise : ni arbre ni voiture.
static func _road_mask(nav: ZoneNavData, roads: Array) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(nav.size.x * nav.size.y)
	for road: Dictionary in roads:
		var sidewalk := 0.0 if road["kind"] in NO_SIDEWALK else SIDEWALK_WIDTH
		var reach: float = road["width"] / 2.0 + sidewalk + TREE_ROAD_MARGIN + CELL_REACH
		var points := _points(road["points"])
		for index: int in points.size() - 1:
			var a := points[index]
			var b := points[index + 1]
			var low := nav.cell_of(Vector3(minf(a.x, b.x) - reach, 0.0, minf(a.y, b.y) - reach))
			var high := nav.cell_of(Vector3(maxf(a.x, b.x) + reach, 0.0, maxf(a.y, b.y) + reach))
			for y: int in range(maxi(low.y, 0), mini(high.y + 1, nav.size.y)):
				for x: int in range(maxi(low.x, 0), mini(high.x + 1, nav.size.x)):
					var center := nav.center_of(Vector2i(x, y))
					var spot := Vector2(center.x, center.z)
					if (
						Geometry2D.get_closest_point_to_segment(spot, a, b).distance_to(spot)
						<= reach
					):
						mask[y * nav.size.x + x] = 1
	return mask


static func _masked(mask: PackedByteArray, nav: ZoneNavData, spot: Vector2) -> bool:
	var cell := nav.cell_of(Vector3(spot.x, 0.0, spot.y))
	return not nav.contains(cell) or mask[cell.y * nav.size.x + cell.x] != 0


# --- Parkings --------------------------------------------------------------


static func _add_parkings(
	root: Node3D,
	markings: SurfaceTool,
	placer: Placer,
	parkings: Array[PackedVector2Array],
	road_mask: PackedByteArray,
	rng: RandomNumberGenerator,
	palette: Dictionary
) -> void:
	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for polygon: PackedVector2Array in parkings:
		MeshKit.add_polygon(asphalt, polygon, PARKING_Y, palette[PARKING_COLOR])
		_add_stalls(markings, placer, polygon, road_mask, rng, palette[MARKING_COLOR])
	MeshKit.commit(root, "Parkings", asphalt, MATERIAL)


# Rangées de places le long du plus grand côté : une rangée, une allée, une rangée
# tournée vers la même allée, et ainsi de suite.
static func _add_stalls(
	markings: SurfaceTool,
	placer: Placer,
	polygon: PackedVector2Array,
	road_mask: PackedByteArray,
	rng: RandomNumberGenerator,
	line_color: Color
) -> void:
	var u := Vector2.RIGHT
	var longest := 0.0
	for index: int in polygon.size():
		var edge := polygon[(index + 1) % polygon.size()] - polygon[index]
		if edge.length() > longest:
			longest = edge.length()
			u = edge.normalized()
	var v := Vector2(-u.y, u.x)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector2 in polygon:
		var local := Vector2(point.dot(u), point.dot(v))
		low = low.min(local)
		high = high.max(local)
	var period := STALL_DEPTH * 2.0 + AISLE_WIDTH
	var row := low.y + STALL_MARGIN
	while row + STALL_DEPTH <= high.y:
		for facing: float in [1.0, -1.0]:
			var row_start := row if facing > 0.0 else row + STALL_DEPTH + AISLE_WIDTH
			if row_start + STALL_DEPTH > high.y:
				continue
			var column := low.x + STALL_MARGIN
			while column + STALL_WIDTH <= high.x:
				var corners: Array[Vector2] = []
				for corner: Vector2 in [
					Vector2(0.0, 0.0),
					Vector2(STALL_WIDTH, 0.0),
					Vector2(STALL_WIDTH, STALL_DEPTH),
					Vector2(0.0, STALL_DEPTH),
				]:
					corners.append(u * (column + corner.x) + v * (row_start + corner.y))
				var roll := rng.randf()
				var model := CAR_MODELS[rng.randi() % CAR_MODELS.size()]
				if _stall_fits(corners, polygon, road_mask, placer.geometry.nav_data):
					var side := PackedVector2Array([corners[0], corners[3]])
					MeshKit.add_ribbon(markings, side, STALL_LINE_WIDTH, MARKING_Y, line_color)
					if roll < CAR_RATE:
						var center := (corners[0] + corners[2]) / 2.0
						var front := v * facing
						_park(
							placer,
							model,
							Vector3(center.x, 0.0, center.y),
							atan2(-front.x, -front.y)
						)
				column += STALL_WIDTH
		row += period


static func _stall_fits(
	corners: Array[Vector2],
	polygon: PackedVector2Array,
	road_mask: PackedByteArray,
	nav: ZoneNavData
) -> bool:
	for corner: Vector2 in corners:
		if not Geometry2D.is_point_in_polygon(corner, polygon):
			return false
		if _masked(road_mask, nav, corner) or nav.is_solid_at(Vector3(corner.x, 0.0, corner.y)):
			return false
	return true


static func _park(placer: Placer, model: String, at: Vector3, yaw: float) -> void:
	placer.place(model, at, yaw)
	var bounds := placer.bounds(model)
	var center := at + Basis(Vector3.UP, yaw) * bounds.get_center()
	placer.obstacle(center, bounds.size, yaw)


# --- Entrées, clôtures, mobilier ------------------------------------------


static func _add_entrances(geometry: ZoneGeometry, placer: Placer, entrances: Array) -> void:
	for entrance: Dictionary in entrances:
		var normal := Vector3(entrance["normal"][0], 0.0, entrance["normal"][1]).normalized()
		var position := Vector3(entrance["x"], 0.0, entrance["z"])
		placer.place(
			ENTRANCE_MODEL, position + normal * ENTRANCE_DEPTH, atan2(-normal.x, -normal.z)
		)
		(
			geometry
			. entrances
			. append(
				{
					"position": position,
					"normal": normal,
					"building": int(entrance["building"]),
					"kind": str(entrance["kind"]),
				}
			)
		)


static func _add_barriers(
	root: Node3D, placer: Placer, barriers: Array, gates: Array, palette: Dictionary
) -> void:
	var see_through := SurfaceTool.new()
	see_through.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid := SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gate_points := _points(gates)
	for barrier: Dictionary in barriers:
		var style: Dictionary = BARRIERS.get(barrier["kind"], {})
		if style.is_empty():
			continue
		var points := _points(barrier["points"])
		for index: int in points.size() - 1:
			for piece: PackedVector2Array in _open_at_gates(
				points[index], points[index + 1], gate_points
			):
				var a := piece[0]
				var b := piece[1]
				var length := a.distance_to(b)
				if length < STALL_LINE_WIDTH:
					continue
				var yaw := -atan2(b.y - a.y, b.x - a.x)
				var height: float = style["height"]
				var width: float = style["width"]
				var middle := (a + b) / 2.0
				var collision := Vector3(
					length,
					maxf(height, BARRIER_MIN_COLLISION.y),
					maxf(width, BARRIER_MIN_COLLISION.x)
				)
				placer.obstacle(
					Vector3(middle.x, collision.y / 2.0, middle.y), collision, yaw, false
				)
				_block_line(placer.geometry.nav_data, a, b, not barrier["kind"] in SEE_THROUGH)
				var color: Color = palette[style["color"]]
				if barrier["kind"] in SEE_THROUGH:
					_add_panel(see_through, a, b, height, color)
				else:
					var top: Color = palette[style.get("top", style["color"])]
					var center := Vector3(middle.x, height / 2.0, middle.y)
					_add_block(solid, center, Vector3(length, height, width), yaw, color, top)
	MeshKit.commit(root, "Fences", see_through, FENCE_MATERIAL)
	MeshKit.commit(root, "Hedges", solid, MATERIAL)


# Découpe le segment [a, b] en morceaux qui laissent une ouverture à chaque portail.
static func _open_at_gates(
	a: Vector2, b: Vector2, gates: PackedVector2Array
) -> Array[PackedVector2Array]:
	var length := a.distance_to(b)
	var cuts: Array[Vector2] = []
	if length > 0.0:
		for gate: Vector2 in gates:
			var foot := Geometry2D.get_closest_point_to_segment(gate, a, b)
			if foot.distance_to(gate) <= GATE_GAP / 2.0:
				var t := a.distance_to(foot) / length
				var half := GATE_GAP / 2.0 / length
				cuts.append(Vector2(t - half, t + half))
	cuts.sort()
	var pieces: Array[PackedVector2Array] = []
	var start := 0.0
	for cut: Vector2 in cuts:
		if cut.x > start:
			pieces.append(PackedVector2Array([a.lerp(b, start), a.lerp(b, cut.x)]))
		start = maxf(start, cut.y)
	if start < 1.0:
		pieces.append(PackedVector2Array([a.lerp(b, start), b]))
	return pieces


# Bouche les cases dont le centre est près du segment, sans déborder de ses extrémités ;
# une haie ou un mur cachent aussi la vue (`opaque`), pas une grille.
static func _block_line(nav: ZoneNavData, a: Vector2, b: Vector2, opaque: bool) -> void:
	var low := nav.cell_of(Vector3(minf(a.x, b.x) - 1.0, 0.0, minf(a.y, b.y) - 1.0))
	var high := nav.cell_of(Vector3(maxf(a.x, b.x) + 1.0, 0.0, maxf(a.y, b.y) + 1.0))
	var direction := (b - a).normalized()
	var length := a.distance_to(b)
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var center := nav.center_of(Vector2i(x, y))
			var offset := Vector2(center.x, center.z) - a
			var along := offset.dot(direction)
			var across := absf(offset.cross(direction))
			if along >= 0.0 and along <= length and across <= BARRIER_NAV_REACH:
				nav.set_solid(Vector2i(x, y))
				if opaque:
					nav.set_opaque(Vector2i(x, y))


# Un pan de grille, vu des deux côtés : UV = (distance le long, hauteur), UV2.y = hauteur.
static func _add_panel(
	surface: SurfaceTool, a: Vector2, b: Vector2, height: float, color: Color
) -> void:
	var corners: Array[Vector3] = [
		Vector3(a.x, 0.0, a.y),
		Vector3(b.x, 0.0, b.y),
		Vector3(b.x, height, b.y),
		Vector3(a.x, height, a.y)
	]
	var length := a.distance_to(b)
	var uvs: Array[Vector2] = [
		Vector2(0.0, 0.0), Vector2(length, 0.0), Vector2(length, height), Vector2(0.0, height)
	]
	var normal := Vector3(b.y - a.y, 0.0, a.x - b.x).normalized()
	var unused := PackedVector3Array()
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		var picked: Array[Vector3] = []
		var picked_uvs: Array[Vector2] = []
		for corner: int in triangle:
			picked.append(corners[corner])
			picked_uvs.append(uvs[corner])
		MeshKit.add_triangle(
			surface, unused, picked, normal, color, picked_uvs, Vector2(0.0, height)
		)


# Une boîte pleine (haie, muret) : côtés d'une couleur, dessus d'une autre.
static func _add_block(
	surface: SurfaceTool, center: Vector3, size: Vector3, yaw: float, sides: Color, top: Color
) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var half := size / 2.0
	var faces := {
		Vector3.UP: [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)],
		Vector3.RIGHT: [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)],
		Vector3.LEFT:
		[Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1)],
		Vector3.BACK: [Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1)],
		Vector3.FORWARD:
		[Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)],
	}
	for normal: Vector3 in faces:
		var corners: Array[Vector3] = []
		for sign: Vector3 in faces[normal]:
			corners.append(center + basis * (sign * half))
		MeshKit.add_quad(surface, corners, basis * normal, top if normal == Vector3.UP else sides)


static func _add_furniture(placer: Placer, furniture: Array, power_lines: Array) -> void:
	for item: Dictionary in furniture:
		var model: String = FURNITURE_MODELS.get(item["kind"], "")
		if model.is_empty():
			continue
		var at := Vector3(item["x"], 0.0, item["z"])
		var angle: float = item["angle"]
		if item["kind"] == "pylone":
			# Les consoles d'un pylône sont en travers de sa ligne.
			angle = _line_angle(Vector2(at.x, at.z), power_lines) + PI / 2.0
		var yaw := -angle
		var scale: float = FURNITURE_SCALE.get(item["kind"], 1.0)
		placer.place(model, at, yaw, scale)
		var bounds := placer.bounds(model)
		var size := bounds.size * scale
		var center := at + Basis(Vector3.UP, yaw) * (bounds.get_center() * scale)
		if item["kind"] == "pylone":
			size.y = PYLON_COLLISION_HEIGHT
			center.y = size.y / 2.0
		placer.obstacle(center, size, yaw)


static func _line_angle(at: Vector2, lines: Array) -> float:
	var best := INF
	var angle := 0.0
	for line: Dictionary in lines:
		var points := _points(line["points"])
		for index: int in points.size() - 1:
			var foot := Geometry2D.get_closest_point_to_segment(
				at, points[index], points[index + 1]
			)
			if foot.distance_to(at) < best:
				best = foot.distance_to(at)
				var direction := points[index + 1] - points[index]
				angle = atan2(direction.y, direction.x)
	return angle


# --- Arbres et lampadaires --------------------------------------------------


static func _add_trees(
	placer: Placer,
	zone: Dictionary,
	road_mask: PackedByteArray,
	parkings: Array[PackedVector2Array],
	rng: RandomNumberGenerator
) -> void:
	var nav := placer.geometry.nav_data
	var planted := {}
	for point: Array in zone.get("trees", []):
		_plant(placer, Vector2(point[0], point[1]), rng, planted, false)
	for area: Dictionary in zone.get("green", []):
		var rule: Array = TREE_SCATTER.get(area["kind"], [])
		if rule.is_empty():
			continue
		var polygon := _points(area["points"])
		var step: float = rule[0]
		var rate: float = rule[1]
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point: Vector2 in polygon:
			low = low.min(point)
			high = high.max(point)
		for gz: int in range(floori(low.y / step), ceili(high.y / step)):
			for gx: int in range(floori(low.x / step), ceili(high.x / step)):
				var spot := Vector2((gx + rng.randf()) * step, (gz + rng.randf()) * step)
				var roll := rng.randf()
				if roll >= rate + BUSH_RATE or not Geometry2D.is_point_in_polygon(spot, polygon):
					continue
				if _masked(road_mask, nav, spot) or nav.is_solid_at(Vector3(spot.x, 0.0, spot.y)):
					continue
				if _inside_any(spot, parkings) or _crowded(planted, spot):
					continue
				_plant(placer, spot, rng, planted, roll >= rate)


static func _plant(
	placer: Placer, spot: Vector2, rng: RandomNumberGenerator, planted: Dictionary, bush: bool
) -> void:
	var model := BUSH_MODEL if bush else TREE_MODELS[rng.randi() % TREE_MODELS.size()]
	var yaw := (rng.randi() % 4) * PI / 2.0
	var scale := rng.randf_range(TREE_SCALE_RANGE.x, TREE_SCALE_RANGE.y)
	var at := Vector3(spot.x, 0.0, spot.y)
	placer.place(model, at, yaw, scale)
	var size := BUSH_SIZE if bush else TRUNK_SIZE
	placer.obstacle(at + Vector3.UP * size.y / 2.0, size, 0.0)
	var cell := Vector2i(floori(spot.x / TREE_SPACING), floori(spot.y / TREE_SPACING))
	if not planted.has(cell):
		planted[cell] = []
	planted[cell].append(spot)


static func _crowded(planted: Dictionary, spot: Vector2) -> bool:
	var cell := Vector2i(floori(spot.x / TREE_SPACING), floori(spot.y / TREE_SPACING))
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			for other: Vector2 in planted.get(cell + Vector2i(dx, dy), []):
				if other.distance_to(spot) < TREE_SPACING:
					return true
	return false


static func _add_lamps(geometry: ZoneGeometry, placer: Placer, roads: Array) -> void:
	var nav := geometry.nav_data
	var spots: Array[Vector2] = []
	for road: Dictionary in roads:
		if road["kind"] in NO_SIDEWALK:
			continue
		var points := _points(road["points"])
		var offset: float = road["width"] / 2.0 + LAMP_SIDE_OFFSET
		var along := LAMP_SPACING / 2.0
		var side := 1.0
		for index: int in points.size() - 1:
			var start := points[index]
			var length := start.distance_to(points[index + 1])
			if length <= 0.0:
				continue
			var direction := (points[index + 1] - start) / length
			var normal := Vector2(-direction.y, direction.x) * side
			while along <= length:
				var spot := start + direction * along + normal * offset
				along += LAMP_SPACING
				var crowded := spots.any(
					func(other: Vector2) -> bool: return other.distance_to(spot) < LAMP_MIN_GAP
				)
				if crowded or nav.is_solid_at(Vector3(spot.x, 0.0, spot.y)):
					continue
				spots.append(spot)
				# La crosse se tend vers la rue.
				var yaw := atan2(normal.x, normal.y)
				var at := Vector3(spot.x, 0.0, spot.y)
				var basis := Basis(Vector3.UP, yaw)
				placer.place(LAMP_MODEL, at, yaw)
				placer.obstacle(at + basis * LAMP_POLE, POLE_SIZE, yaw, false)
				geometry.lamp_positions.append(at + basis * LAMP_HEAD)
				side = -side
				normal = -normal
			along -= length


# --- Aides -------------------------------------------------------------------


static func _points(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for pair: Array in raw:
		points.append(Vector2(pair[0], pair[1]))
	return points


static func _polygons(areas: Array) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for area: Dictionary in areas:
		polygons.append(_points(area["points"]))
	return polygons


static func _inside_any(spot: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon: PackedVector2Array in polygons:
		if Geometry2D.is_point_in_polygon(spot, polygon):
			return true
	return false


## Rassemble les objets à poser, leurs collisions et les cases qu'ils bouchent, puis les
## écrit d'un coup dans la scène.
class Placer:
	extends RefCounted

	var geometry: ZoneGeometry
	## modèle → [[maillage, position de la partie dans le modèle], …]
	var _models := {}
	var _bounds := {}
	## « modèle|x|z » → [Transform3D, …]
	var _instances := {}
	## carré → triangles de collision
	var _faces := {}

	func _init(target: ZoneGeometry) -> void:
		geometry = target

	## Boîte englobante du modèle, dans son repère.
	func bounds(model: String) -> AABB:
		_load(model)
		return _bounds.get(model, AABB())

	func place(model: String, at: Vector3, yaw: float, scale: float = 1.0) -> void:
		_load(model)
		var transform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at)
		var key := "%s|%d|%d" % [model, floori(at.x / CHUNK_SIZE), floori(at.z / CHUNK_SIZE)]
		if not _instances.has(key):
			_instances[key] = []
		_instances[key].append(transform)

	## Un obstacle : une boîte (centre, taille, lacet) qui arrête Akan et, si `blocks_nav`,
	## bouche les cases de navigation qu'elle couvre.
	func obstacle(center: Vector3, size: Vector3, yaw: float, blocks_nav: bool = true) -> void:
		var basis := Basis(Vector3.UP, yaw)
		var chunk := Vector2i(floori(center.x / CHUNK_SIZE), floori(center.z / CHUNK_SIZE))
		var faces: PackedVector3Array = _faces.get(chunk, PackedVector3Array())
		faces.append_array(ZoneDressing.box_faces(center, size, basis))
		_faces[chunk] = faces
		if blocks_nav:
			_block(center, size, basis)

	func commit(root: Node3D) -> void:
		var keys: Array = _instances.keys()
		keys.sort()
		for key: String in keys:
			var parts := key.split("|")
			var transforms: Array = _instances[key]
			var model_parts: Array = _models[parts[0]]
			for part_index: int in model_parts.size():
				var local: Transform3D = model_parts[part_index][1]
				var instances := PropInstances.new()
				instances.name = "%s_%s_%s_%d" % [parts[0], parts[1], parts[2], part_index]
				instances.model = parts[0]
				instances.instance_mesh = model_parts[part_index][0]
				instances.material_override = MATERIAL
				for transform: Transform3D in transforms:
					instances.transforms.append(transform * local)
				root.add_child(instances)
		if _faces.is_empty():
			return
		var body := StaticBody3D.new()
		body.name = "Body"
		root.add_child(body)
		var chunks: Array = _faces.keys()
		chunks.sort()
		for chunk: Vector2i in chunks:
			var shape := ConcavePolygonShape3D.new()
			# Les boîtes sont fermées : peu importe le sens de leurs faces.
			shape.backface_collision = true
			shape.set_faces(_faces[chunk])
			MeshKit.add_shape(body, shape, Vector3.ZERO)

	func _load(model: String) -> void:
		if _models.has(model):
			return
		var parts: Array = []
		var scene := VoxelModel.instantiate(PROP_FOLDER + model)
		if scene != null:
			for part: MeshInstance3D in VoxelModel.parts(scene):
				# Une copie du maillage : il est enregistré avec la zone, pas emprunté à l'import.
				parts.append([part.mesh.duplicate(), VoxelModel.local_transform(part, scene)])
			_bounds[model] = VoxelModel.bounds(scene)
			scene.free()
		_models[model] = parts

	# Bouche les cases dont le centre tombe sous la boîte, un peu élargie.
	func _block(center: Vector3, size: Vector3, basis: Basis) -> void:
		var nav := geometry.nav_data
		var half := Vector2(size.x, size.z) / 2.0 + Vector2.ONE * ZoneGeometryBuilder.NAV_MARGIN
		var reach := half.length()
		var low := nav.cell_of(center - Vector3(reach, 0.0, reach))
		var high := nav.cell_of(center + Vector3(reach, 0.0, reach))
		for y: int in range(low.y, high.y + 1):
			for x: int in range(low.x, high.x + 1):
				var cell := Vector2i(x, y)
				var offset := nav.center_of(cell) - Vector3(center.x, 0.0, center.z)
				var local := offset * basis
				if absf(local.x) <= half.x and absf(local.z) <= half.y:
					nav.set_solid(cell)
