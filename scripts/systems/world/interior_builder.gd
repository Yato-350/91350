class_name InteriorBuilder
## Construit un intérieur à partir d'un plan en texte (data/interiors/*.json), une case
## par mètre : « # » mur, une majuscule un pan de mur particulier (« D » porte, « E »
## ascenseur, « S » escalier), « espace » le vide, « . » du sol. Les autres caractères
## sont déclarés par l'intérieur : « floors » (un autre sol), « markers » (un repère :
## lit, porte, point d'arrivée) ou « props » (un meuble ; des cases voisines de même
## caractère forment un seul meuble, posé en leur milieu).
##
## Les murs sont fins, au milieu de leur case, et dessinés bas (coupés à hauteur de
## hanche) pour voir dans les pièces ; leur collision monte plus haut.

const MATERIAL := preload("res://assets/materials/prop.tres")
const WALL := "#"
const VOID := " "
const CELL := 1.0
const WALL_HEIGHT := 0.9
const WALL_THICKNESS := 0.25
const COLLISION_HEIGHT := 3.0
const FLOOR_THICKNESS := 1.0
const FLOOR := "."
const DEFAULT_MARKER := "default"
const PROP_MODEL_PATH := "props/%s"
const FLOOR_COLOR := "brun_2"
const WALL_COLOR := "creme"
## Le dessus des murs, là où passe la coupe.
const CUT_COLOR := "noir"
## Le dos des murs, tourné vers le vide : sombre, pour détacher les pièces du fond.
const OUTSIDE_COLOR := "beton_1"
## Couleur des pans de mur particuliers.
const SPECIAL_WALLS := {"D": "brun_1", "E": "bleu_acier", "S": "beton_2"}
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const QUADRANTS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)
]


static func build(definition: Dictionary, palette: Dictionary) -> ZoneGeometry:
	var rows := _rows(definition)
	var size := Vector2i(_width(rows), rows.size())
	var geometry := ZoneGeometry.new()
	geometry.name = "Geometry"
	geometry.zone_id = definition.get("id", "")
	geometry.zone_size = Vector2(size) * CELL
	geometry.nav_data = ZoneNavData.create(geometry.zone_size, CELL)
	var names: Dictionary = definition.get("markers", {})
	var props: Dictionary = definition.get("props", {})
	var floor_colors: Dictionary = definition.get("floors", {})
	var floor_color: String = definition.get("floor_color", FLOOR_COLOR)
	var wall_color: String = definition.get("wall_color", WALL_COLOR)
	var floor_surface := SurfaceTool.new()
	floor_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_surface := SurfaceTool.new()
	wall_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y: int in size.y:
		for x: int in size.x:
			var cell := Vector2i(x, y)
			var kind := _kind(rows, cell)
			var center := _center_of(rows, cell)
			if kind == VOID:
				geometry.nav_data.set_solid(cell)
			elif _is_wall(kind):
				geometry.nav_data.set_solid(cell)
				var colors: Array[Color] = []
				for side: Vector2i in SIDES:
					var outside := (
						not _is_inside(rows, cell + side) or _kind(rows, cell + side) == VOID
					)
					var color_id: String = (
						OUTSIDE_COLOR if outside else SPECIAL_WALLS.get(kind, wall_color)
					)
					colors.append(palette[color_id])
				_add_wall(wall_surface, rows, cell, center, colors, palette[CUT_COLOR])
				_add_floor_under_wall(
					floor_surface, rows, cell, center, floor_colors, floor_color, palette
				)
			else:
				var half := Vector2.ONE * CELL / 2.0
				var color: Color = palette[_floor_color_of(rows, cell, floor_colors, floor_color)]
				_add_floor(floor_surface, center, -half, half, color)
				if names.has(kind):
					geometry.markers[names[kind]] = center
				var prop: Dictionary = props.get(kind, {})
				if not prop.is_empty() and prop.get("solid", true):
					geometry.nav_data.set_solid(cell)
	MeshKit.commit(geometry, "Floor", floor_surface, MATERIAL)
	MeshKit.commit(geometry, "Walls", wall_surface, MATERIAL)
	_add_collisions(geometry, rows, size)
	return geometry


## Les meubles du plan : [{"model", "yaw", "solid", "position"}], un par groupe de cases
## voisines portant le même caractère.
static func prop_placements(definition: Dictionary) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	var rows := _rows(definition)
	var props: Dictionary = definition.get("props", {})
	var visited := {}
	for y: int in rows.size():
		for x: int in _width(rows):
			var cell := Vector2i(x, y)
			var kind := _kind(rows, cell)
			if not props.has(kind) or visited.has(cell):
				continue
			var group: Array[Vector2i] = [cell]
			visited[cell] = true
			var index := 0
			while index < group.size():
				for side: Vector2i in SIDES:
					var next := group[index] + side
					var same := _is_inside(rows, next) and _kind(rows, next) == kind
					if same and not visited.has(next):
						visited[next] = true
						group.append(next)
				index += 1
			var middle := Vector3.ZERO
			for member: Vector2i in group:
				middle += _center_of(rows, member) / group.size()
			var prop: Dictionary = props[kind]
			(
				placements
				. append(
					{
						"model": prop.get("model", ""),
						"yaw": float(prop.get("yaw", 0.0)),
						"solid": prop.get("solid", true),
						"position": middle,
					}
				)
			)
	return placements


## Rend les défauts du plan (liste vide s'il est sain) : un plan mal fermé laisserait
## Akan sortir du décor.
static func plan_errors(definition: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var rows := _rows(definition)
	if rows.is_empty():
		return ["plan absent ou vide"]
	for y: int in rows.size():
		if rows[y].length() != _width(rows):
			return ["largeur : la ligne %d n'a pas la longueur de la première" % y]
	var names: Dictionary = definition.get("markers", {})
	var props: Dictionary = definition.get("props", {})
	var floor_colors: Dictionary = definition.get("floors", {})
	var seen := {}
	for y: int in rows.size():
		for x: int in _width(rows):
			var cell := Vector2i(x, y)
			var kind := _kind(rows, cell)
			if kind == VOID or _is_wall(kind):
				continue
			if x == 0 or y == 0 or x == _width(rows) - 1 or y == rows.size() - 1:
				errors.append("sol au bord du plan en %s" % cell)
			for side: Vector2i in SIDES:
				if _kind(rows, cell + side) == VOID:
					errors.append("sol ouvert sur le vide en %s" % cell)
			var known := (
				kind == FLOOR or floor_colors.has(kind) or names.has(kind) or props.has(kind)
			)
			if not known:
				errors.append("caractère inconnu « %s » en %s" % [kind, cell])
			if names.has(kind) and seen.has(kind):
				errors.append("repère %s posé deux fois" % kind)
			seen[kind] = true
	for marker: String in names:
		if not seen.has(marker):
			errors.append("repère %s absent du plan" % marker)
	if not DEFAULT_MARKER in names.values():
		errors.append("aucun repère « %s »" % DEFAULT_MARKER)
	for kind: String in props:
		var model: String = props[kind].get("model", "")
		if not ResourceLoader.exists(VoxelModel.PATH % (PROP_MODEL_PATH % model)):
			errors.append("meuble sans modèle : %s" % model)
	return errors


static func _rows(definition: Dictionary) -> PackedStringArray:
	return PackedStringArray(definition.get("plan", []))


static func _width(rows: PackedStringArray) -> int:
	return rows[0].length() if not rows.is_empty() else 0


## Le caractère du plan en `cell`, ou un mur hors du plan.
static func _kind(rows: PackedStringArray, cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= rows[cell.y].length():
		return WALL
	return rows[cell.y][cell.x]


static func _is_wall(kind: String) -> bool:
	return kind == WALL or (kind >= "A" and kind <= "Z")


## Centre de la case, le plan étant centré sur l'origine (comme ZoneNavData).
static func _center_of(rows: PackedStringArray, cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5 - _width(rows) / 2.0) * CELL, 0.0, (cell.y + 0.5 - rows.size() / 2.0) * CELL
	)


# Couleur du sol d'une case. Un repère ou un meuble n'en dit rien : il prend le sol de la
# case voisine, pour ne pas faire de tache dans la pièce.
static func _floor_color_of(
	rows: PackedStringArray, cell: Vector2i, floor_colors: Dictionary, floor_color: String
) -> String:
	var kind := _kind(rows, cell)
	if floor_colors.has(kind):
		return floor_colors[kind]
	if kind != FLOOR:
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var beside := _kind(rows, cell + side)
			if floor_colors.has(beside):
				return floor_colors[beside]
			if beside == FLOOR:
				break
	return floor_color


# Un rectangle de sol autour de `center`, de `low` à `high` (x, z).
static func _add_floor(
	surface: SurfaceTool, center: Vector3, low: Vector2, high: Vector2, color: Color
) -> void:
	var corners: Array[Vector3] = [
		center + Vector3(low.x, 0.0, low.y),
		center + Vector3(high.x, 0.0, low.y),
		center + Vector3(high.x, 0.0, high.y),
		center + Vector3(low.x, 0.0, high.y),
	]
	MeshKit.add_quad(surface, corners, Vector3.UP, color)


# Le mur est au milieu de sa case : chaque quart de case tourné vers une pièce reçoit
# le sol de cette pièce, pour qu'il aille jusqu'au pied du mur.
static func _add_floor_under_wall(
	surface: SurfaceTool,
	rows: PackedStringArray,
	cell: Vector2i,
	center: Vector3,
	floor_colors: Dictionary,
	floor_color: String,
	palette: Dictionary
) -> void:
	var half := CELL / 2.0
	for quadrant: Vector2i in QUADRANTS:
		var around: Array[Vector2i] = [Vector2i(quadrant.x, 0), Vector2i(0, quadrant.y), quadrant]
		for offset: Vector2i in around:
			var kind := _kind(rows, cell + offset)
			if kind == VOID or _is_wall(kind):
				continue
			var corner := Vector2(quadrant) * half
			var color: Color = palette[_floor_color_of(
				rows, cell + offset, floor_colors, floor_color
			)]
			_add_floor(surface, center, corner.min(Vector2.ZERO), corner.max(Vector2.ZERO), color)
			break


# Un mur fin : un poteau au centre de la case et un bras vers chaque mur voisin.
# `colors` donne la couleur de chaque côté, dans l'ordre de SIDES.
static func _add_wall(
	surface: SurfaceTool,
	rows: PackedStringArray,
	cell: Vector2i,
	center: Vector3,
	colors: Array[Color],
	cut_color: Color
) -> void:
	var thin := WALL_THICKNESS / 2.0
	var arms: Array[Vector2i] = []
	for side: Vector2i in SIDES:
		if _is_wall_inside(rows, cell + side):
			arms.append(side)
	_add_block(surface, center, Vector2(-thin, -thin), Vector2(thin, thin), arms, colors, cut_color)
	for arm: Vector2i in arms:
		# Le bras va du poteau au bord de la case ; ses deux bouts sont cachés.
		var along := Vector2(arm)
		var across := Vector2(absf(along.y), absf(along.x)) * thin
		var near := along * thin
		var far := along * CELL / 2.0
		var hidden: Array[Vector2i] = [arm, -arm]
		_add_block(
			surface,
			center,
			near.min(far) - across,
			near.max(far) + across,
			hidden,
			colors,
			cut_color
		)


# Un bloc bas de `low` à `high` (x, z) : son dessus (la coupe) et ses côtés, sauf ceux
# de `hidden_sides`, collés à un autre bloc.
static func _add_block(
	surface: SurfaceTool,
	center: Vector3,
	low: Vector2,
	high: Vector2,
	hidden_sides: Array[Vector2i],
	colors: Array[Color],
	cut_color: Color
) -> void:
	var top := Vector3.UP * WALL_HEIGHT
	var corners: Array[Vector3] = [
		center + Vector3(low.x, 0.0, low.y),
		center + Vector3(high.x, 0.0, low.y),
		center + Vector3(high.x, 0.0, high.y),
		center + Vector3(low.x, 0.0, high.y),
	]
	var cut: Array[Vector3] = []
	for corner: Vector3 in corners:
		cut.append(corner + top)
	MeshKit.add_quad(surface, cut, Vector3.UP, cut_color)
	# Le côté i relie les coins i et i + 1 : nord, est, sud, ouest, comme SIDES.
	for index: int in SIDES.size():
		if SIDES[index] in hidden_sides:
			continue
		var from := corners[index]
		var to := corners[(index + 1) % corners.size()]
		var face: Array[Vector3] = [from, to, to + top, from + top]
		MeshKit.add_quad(surface, face, Vector3(SIDES[index].x, 0.0, SIDES[index].y), colors[index])


# Une dalle sous tout le plan, et une boîte fine par rangée et par colonne de murs contigus.
static func _add_collisions(
	geometry: ZoneGeometry, rows: PackedStringArray, size: Vector2i
) -> void:
	var slab := BoxShape3D.new()
	slab.size = Vector3(size.x * CELL, FLOOR_THICKNESS, size.y * CELL)
	var body := MeshKit.add_body(geometry, "Body", slab, Vector3.ZERO)
	body.get_child(0).position = Vector3(0.0, -FLOOR_THICKNESS / 2.0, 0.0)
	for y: int in size.y:
		_add_wall_runs(body, geometry.nav_data, rows, Vector2i(0, y), Vector2i.RIGHT, size.x)
	for x: int in size.x:
		_add_wall_runs(body, geometry.nav_data, rows, Vector2i(x, 0), Vector2i.DOWN, size.y)


# Parcourt une ligne de cases depuis `start` dans la direction `step` et pose une boîte
# par suite de murs contigus.
static func _add_wall_runs(
	body: StaticBody3D,
	nav: ZoneNavData,
	rows: PackedStringArray,
	start: Vector2i,
	step: Vector2i,
	count: int
) -> void:
	var across := Vector2i(step.y, step.x)
	var run_start := -1
	for index: int in count + 1:
		var solid := index < count and _is_wall(_kind(rows, start + step * index))
		if solid and run_start == -1:
			run_start = index
		elif not solid and run_start != -1:
			var first := start + step * run_start
			var length := index - run_start
			run_start = -1
			# Un mur seul sur sa rangée appartient à sa colonne ; s'il est seul des deux
			# côtés, c'est un poteau, que sa rangée prend en charge.
			var crossed := (
				_is_wall_inside(rows, first + across) or _is_wall_inside(rows, first - across)
			)
			if length == 1 and (crossed or step == Vector2i.DOWN):
				continue
			var long := (length - 1) * CELL + WALL_THICKNESS
			var box := BoxShape3D.new()
			box.size = Vector3(
				long if step.x != 0 else WALL_THICKNESS,
				COLLISION_HEIGHT,
				long if step.y != 0 else WALL_THICKNESS
			)
			var middle := (
				nav.center_of(first) + Vector3(step.x, 0.0, step.y) * (length - 1) * CELL / 2.0
			)
			MeshKit.add_shape(body, box, middle + Vector3.UP * COLLISION_HEIGHT / 2.0)


static func _is_inside(rows: PackedStringArray, cell: Vector2i) -> bool:
	return cell.y >= 0 and cell.y < rows.size() and cell.x >= 0 and cell.x < _width(rows)


# Comme _is_wall, mais hors du plan il n'y a rien : pas de mur à rejoindre.
static func _is_wall_inside(rows: PackedStringArray, cell: Vector2i) -> bool:
	return _is_inside(rows, cell) and _is_wall(_kind(rows, cell))
