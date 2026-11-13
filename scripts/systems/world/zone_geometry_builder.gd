class_name ZoneGeometryBuilder
## Construit la géométrie statique d'une zone à partir des données dérivées d'OpenStreetMap
## (voir tools/osm_import/) : sol, espaces verts, eau, routes, voies ferrées, bâtiments
## extrudés, collisions, limites de la zone et grille de navigation.
##
## Repère : x vers l'est, z vers le sud, origine au centre de la zone, sol à y = 0.

const BUILDING_MATERIAL := preload("res://assets/materials/building.tres")
const VERTEX_COLOR_MATERIAL := preload("res://assets/materials/vertex_color.tres")
## Les bâtiments sont fusionnés par carrés de cette taille (un maillage par carré).
const CHUNK_SIZE := 64.0
const GROUND_THICKNESS := 1.0
const BOUNDS_HEIGHT := 6.0
const BOUNDS_THICKNESS := 1.0
## Marge autour des obstacles dans la grille de navigation (demi-largeur d'un personnage).
const NAV_MARGIN := 0.4
# Hauteurs des couches posées sur le sol : quelques centimètres suffisent à les ordonner.
const GREEN_Y := 0.02
const WATER_Y := 0.03
const FOOTWAY_Y := 0.04
const ROAD_Y := 0.05
const RAIL_Y := 0.07
const RAIL_WIDTH := 3.0
const FOOT_KINDS: Array[String] = ["footway", "path", "steps", "cycleway", "pedestrian", "track"]
const GROUND_COLOR := "beton_3"
const ROAD_COLOR := "beton_2"
const FOOTWAY_COLOR := "beton_5"
const RAIL_COLOR := "brun_1"
const WATER_COLOR := "eau_sombre"
const GREEN_COLORS := {"pitch": "vert_feuille", "playground": "orange_sombre"}
const GREEN_DEFAULT_COLOR := "vert_sombre"
## Grigny 2 : des tours claires, béton gris, blanc cassé et beige.
const BUILDING_COLORS: Array[String] = ["beton_5", "creme", "beton_5", "beton_4"]
## Couleurs notées dans OpenStreetMap → couleurs de la palette.
const OSM_COLORS := {
	"white": "blanc",
	"beige": "creme",
	"grey": "beton_4",
	"gray": "beton_4",
	"black": "beton_1",
	"brown": "brun_2",
	"red": "rouge_sombre",
	"yellow": "jaune_linge",
}
const NEUTRAL_COLOR := "creme"
const COMMERCIAL_COLOR := "beton_3"
const ROOF_COLOR := "beton_2"
## Sol intérieur d'un bâtiment, visible seulement quand la vue le découpe.
const FLOOR_COLOR := "beton_1"
const FLOOR_Y := 0.06


static func build(zone: Dictionary, palette: Dictionary) -> ZoneGeometry:
	var geometry := ZoneGeometry.new()
	geometry.name = "Geometry"
	geometry.zone_id = zone.get("zone", "")
	geometry.zone_size = Vector2(zone["size"][0], zone["size"][1])
	geometry.attribution = zone.get("attribution", "")
	geometry.nav_data = ZoneNavData.create(geometry.zone_size)

	_add_ground(geometry, palette)
	_add_flat_layer(geometry, "Green", zone.get("green", []), GREEN_Y, palette, false)
	_add_flat_layer(geometry, "Water", zone.get("water", []), WATER_Y, palette, true)
	_add_roads(geometry, zone.get("roads", []), zone.get("rails", []), palette)
	_add_buildings(geometry, zone.get("buildings", []), palette)
	ZoneDressing.dress(geometry, zone, palette)
	_add_bounds(geometry)
	MeshKit.own(geometry, geometry)
	return geometry


static func _add_ground(geometry: ZoneGeometry, palette: Dictionary) -> void:
	var size := geometry.zone_size
	var plane := PlaneMesh.new()
	plane.size = size
	plane.material = _flat_material(palette[GROUND_COLOR])
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	geometry.add_child(ground)
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, GROUND_THICKNESS, size.y)
	MeshKit.add_body(ground, "Body", box, Vector3(0.0, -GROUND_THICKNESS / 2.0, 0.0))


static func _add_flat_layer(
	geometry: ZoneGeometry, layer: String, areas: Array, y: float, palette: Dictionary, blocks: bool
) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for area: Dictionary in areas:
		var points := _points(area["points"])
		if area.get("kind", "") == "stream":
			MeshKit.add_ribbon(surface, points, RAIL_WIDTH, y, palette[WATER_COLOR])
			continue
		var color_id: String = (
			WATER_COLOR if blocks else GREEN_COLORS.get(area["kind"], GREEN_DEFAULT_COLOR)
		)
		MeshKit.add_polygon(surface, points, y, palette[color_id])
		if blocks:
			_block(geometry.nav_data, points, 0.0)
	MeshKit.commit(geometry, layer, surface, VERTEX_COLOR_MATERIAL)


static func _add_roads(
	geometry: ZoneGeometry, roads: Array, rails: Array, palette: Dictionary
) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for road: Dictionary in roads:
		var on_foot: bool = road["kind"] in FOOT_KINDS
		var color: Color = palette[FOOTWAY_COLOR if on_foot else ROAD_COLOR]
		var y := FOOTWAY_Y if on_foot else ROAD_Y
		MeshKit.add_ribbon(surface, _points(road["points"]), road["width"], y, color)
	for rail: Dictionary in rails:
		MeshKit.add_ribbon(
			surface, _points(rail["points"]), RAIL_WIDTH, RAIL_Y, palette[RAIL_COLOR]
		)
	MeshKit.commit(geometry, "Roads", surface, VERTEX_COLOR_MATERIAL)


static func _add_buildings(geometry: ZoneGeometry, buildings: Array, palette: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Buildings"
	geometry.add_child(root)
	var surfaces := {}
	var faces := {}
	for building: Dictionary in buildings:
		var points := _points(building["points"])
		if points.size() < 3:
			continue
		if _signed_area(points) < 0.0:
			points.reverse()
		var center := Vector2.ZERO
		for point: Vector2 in points:
			center += point / points.size()
		var chunk := Vector2i(floori(center.x / CHUNK_SIZE), floori(center.y / CHUNK_SIZE))
		if not surfaces.has(chunk):
			var created := SurfaceTool.new()
			created.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[chunk] = created
			faces[chunk] = PackedVector3Array()
		var chunk_faces: PackedVector3Array = faces[chunk]
		_add_building(surfaces[chunk], chunk_faces, points, building, palette)
		faces[chunk] = chunk_faces
		_block(geometry.nav_data, points, NAV_MARGIN)
		_mark_opaque(geometry.nav_data, points)
	for chunk: Vector2i in surfaces:
		var instance := MeshKit.commit(
			root, "Chunk_%d_%d" % [chunk.x, chunk.y], surfaces[chunk], BUILDING_MATERIAL
		)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces[chunk])
		MeshKit.add_body(instance, "Body", shape, Vector3.ZERO)


static func _add_building(
	surface: SurfaceTool,
	faces: PackedVector3Array,
	points: PackedVector2Array,
	building: Dictionary,
	palette: Dictionary
) -> void:
	var height: float = building["height"]
	var id: int = building["id"]
	var color: Color = palette[BUILDING_COLORS[id % BUILDING_COLORS.size()]]
	if building.get("neutral", false):
		color = palette[NEUTRAL_COLOR]
	elif building.get("kind", "") == "commercial":
		color = palette[COMMERCIAL_COLOR]
	elif OSM_COLORS.has(building.get("colour", "")):
		color = palette[OSM_COLORS[building["colour"]]]
	# UV2 : (graine propre au bâtiment, hauteur) pour le shader des façades.
	var extra := Vector2(fposmod(id * 0.6180339887, 1.0), height)
	var wall_color := Color(color, 1.0)
	var along := 0.0
	for index: int in points.size():
		var start := points[index]
		var end := points[(index + 1) % points.size()]
		var length := start.distance_to(end)
		var normal := Vector3(end.y - start.y, 0.0, start.x - end.x).normalized()
		var corners: Array[Vector3] = [
			Vector3(start.x, 0.0, start.y),
			Vector3(end.x, 0.0, end.y),
			Vector3(end.x, height, end.y),
			Vector3(start.x, height, start.y),
		]
		var uvs: Array[Vector2] = [
			Vector2(along, 0.0),
			Vector2(along + length, 0.0),
			Vector2(along + length, height),
			Vector2(along, height),
		]
		for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
			var a: int = triangle[0]
			var b: int = triangle[1]
			var c: int = triangle[2]
			MeshKit.add_triangle(
				surface,
				faces,
				[corners[a], corners[b], corners[c]],
				normal,
				wall_color,
				[uvs[a], uvs[b], uvs[c]],
				extra
			)
		along += length
	var roof_id: String = OSM_COLORS.get(building.get("roof_colour", ""), ROOF_COLOR)
	var roof_color := Color(palette[roof_id], 0.0)
	var floor_color := Color(palette[FLOOR_COLOR], 0.0)
	var unused := PackedVector3Array()
	var indices := Geometry2D.triangulate_polygon(points)
	for index: int in range(0, indices.size(), 3):
		var roof: Array[Vector3] = []
		var floor_corners: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for offset: int in 3:
			var point := points[indices[index + offset]]
			roof.append(Vector3(point.x, height, point.y))
			floor_corners.append(Vector3(point.x, FLOOR_Y, point.y))
			uvs.append(point)
		MeshKit.add_triangle(surface, faces, roof, Vector3.UP, roof_color, uvs, extra)
		MeshKit.add_triangle(surface, unused, floor_corners, Vector3.UP, floor_color, uvs, extra)


static func _add_bounds(geometry: ZoneGeometry) -> void:
	var bounds := Node3D.new()
	bounds.name = "Bounds"
	geometry.add_child(bounds)
	var half := geometry.zone_size / 2.0
	var thick := BOUNDS_THICKNESS
	var sides := {
		"North":
		[
			Vector3(0.0, 0.0, -half.y - thick / 2.0),
			Vector3(geometry.zone_size.x + thick * 2.0, 0.0, thick)
		],
		"South":
		[
			Vector3(0.0, 0.0, half.y + thick / 2.0),
			Vector3(geometry.zone_size.x + thick * 2.0, 0.0, thick)
		],
		"West":
		[Vector3(-half.x - thick / 2.0, 0.0, 0.0), Vector3(thick, 0.0, geometry.zone_size.y)],
		"East":
		[Vector3(half.x + thick / 2.0, 0.0, 0.0), Vector3(thick, 0.0, geometry.zone_size.y)],
	}
	for side: String in sides:
		var box := BoxShape3D.new()
		var extent: Vector3 = sides[side][1]
		box.size = Vector3(extent.x, BOUNDS_HEIGHT, extent.z)
		var at: Vector3 = sides[side][0]
		MeshKit.add_body(bounds, side, box, at + Vector3(0.0, BOUNDS_HEIGHT / 2.0, 0.0))


# --- Aides de maillage -----------------------------------------------------


static func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material


# --- Aides de géométrie 2D -------------------------------------------------


static func _points(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for pair: Array in raw:
		points.append(Vector2(pair[0], pair[1]))
	return points


static func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for index: int in points.size():
		var next := points[(index + 1) % points.size()]
		area += points[index].x * next.y - next.x * points[index].y
	return area / 2.0


## Un immeuble cache la vue sur son emprise exacte (la marge de passage ne compte pas).
static func _mark_opaque(nav: ZoneNavData, points: PackedVector2Array) -> void:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point: Vector2 in points:
		low = low.min(point)
		high = high.max(point)
	var from := nav.cell_of(Vector3(low.x, 0.0, low.y))
	var to := nav.cell_of(Vector3(high.x, 0.0, high.y))
	for cell_y: int in range(from.y, to.y + 1):
		for cell_x: int in range(from.x, to.x + 1):
			var cell := Vector2i(cell_x, cell_y)
			var center := nav.center_of(cell)
			if Geometry2D.is_point_in_polygon(Vector2(center.x, center.z), points):
				nav.set_opaque(cell)


## Marque comme pleines les cases dont le centre tombe dans le polygone (élargi de `margin`).
static func _block(nav: ZoneNavData, points: PackedVector2Array, margin: float) -> void:
	var polygons: Array[PackedVector2Array] = [points]
	if margin > 0.0:
		polygons = Geometry2D.offset_polygon(points, margin)
	for polygon: PackedVector2Array in polygons:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point: Vector2 in polygon:
			low = low.min(point)
			high = high.max(point)
		var from := nav.cell_of(Vector3(low.x, 0.0, low.y))
		var to := nav.cell_of(Vector3(high.x, 0.0, high.y))
		for cell_y: int in range(from.y, to.y + 1):
			for cell_x: int in range(from.x, to.x + 1):
				var cell := Vector2i(cell_x, cell_y)
				var center := nav.center_of(cell)
				if Geometry2D.is_point_in_polygon(Vector2(center.x, center.z), polygon):
					nav.set_solid(cell)
