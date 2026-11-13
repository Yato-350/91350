class_name Zone
extends Node3D
## Un lieu du jeu : sa géométrie, sa lumière, le joueur et sa caméra, ses portes.
##
## Une zone extérieure (data/zones/) a une géométrie cuite depuis OpenStreetMap ; un
## intérieur (data/interiors/) est construit à la volée depuis son plan en texte.

const GEOMETRY_PATH := "res://scenes/zones/generated/%s.scn"
const SKY_SCENE := preload("res://scenes/world/sky.tscn")
const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const CAMERA_RIG_SCENE := preload("res://scenes/actors/camera_rig.tscn")
const DEFAULT_MARKER := "default"
const MARKER_SEPARATOR := "@"
const INTERIOR_BACKGROUND := "noir"
## Dans un intérieur, la vue se rapproche : les pièces sont petites.
const INTERIOR_ZOOM := 2
## Hauteur d'apparition au-dessus du sol : le joueur se pose tout seul.
const SPAWN_HEIGHT := 0.1
## Un objectif « aller à un repère » est atteint à cette distance (m).
const GOTO_RADIUS := 2.0
const TARGET_SEPARATOR := ":"
## L'applique d'une entrée : à tant de mètres devant la façade, à tant de hauteur.
const ENTRANCE_LIGHT_OFFSET := Vector2(0.6, 2.6)
## Distance à laquelle on considère qu'Akan arrive par l'entrée d'un immeuble.
const ENTRANCE_REACH := 3.0
## Rayon maximal (en cases) de la recherche d'une case libre.
const FREE_SEARCH_RADIUS := 40

var zone_id := ""
## Repère où Akan arrive en entrant dans le lieu.
var arrival := DEFAULT_MARKER
var definition := {}
var is_interior := false
## Zone de territoire dont dépend le lieu : elle-même, ou celle qui abrite l'intérieur.
var territory_id := ""
var geometry: ZoneGeometry
## Repères du lieu : nom → position.
var markers := {}
var player: Player
## Lanternes des lampadaires posés par les données du lieu (en plus des cuits).
var _extra_lamps := PackedVector3Array()
var _nav_grid: NavGrid


## Rend le lieu demandé, ou null (erreur journalisée) s'il n'existe pas.
## `ref` peut préciser un repère d'arrivée : « grigny2@gare ».
static func create(ref: String) -> Zone:
	var id := ref.get_slice(MARKER_SEPARATOR, 0)
	var zone := Zone.new()
	zone.name = id.capitalize().replace(" ", "")
	zone.zone_id = id
	if ref.contains(MARKER_SEPARATOR):
		zone.arrival = ref.get_slice(MARKER_SEPARATOR, 1)
	zone.definition = DataRegistry.entry("zones", id)
	zone.territory_id = id
	if zone.definition.is_empty():
		zone.definition = DataRegistry.entry("interiors", id)
		zone.is_interior = true
		zone.territory_id = zone.definition.get("territory", "")
	zone.geometry = zone._make_geometry()
	if zone.geometry == null:
		push_error("Zone inconnue : %s" % id)
		zone.free()
		return null
	zone._read_markers()
	return zone


func _ready() -> void:
	add_child(geometry)
	var sky: ZoneSky = SKY_SCENE.instantiate()
	add_child(sky)
	if is_interior:
		sky.use_interior_light(Palette.load_colors()[INTERIOR_BACKGROUND])
	for door: Dictionary in definition.get("doors", []):
		_add_door(door)
	_add_props()
	_add_pickups()
	_add_npcs()
	_add_cameras()
	_add_vigiles()
	EventBus.item_dropped.connect(_on_item_dropped)
	player = PLAYER_SCENE.instantiate()
	player.position = spawn_position(arrival)
	add_child(player)
	var rig: CameraRig = CAMERA_RIG_SCENE.instantiate()
	rig.target = player
	add_child(rig)
	if not is_interior and not (geometry.lamp_positions.is_empty() and _extra_lamps.is_empty()):
		_add_lamp_lights()
	var guide := QuestGuide.new()
	guide.name = "QuestGuide"
	guide.zone = self
	add_child(guide)
	# En sortant d'un immeuble, on voit sa façade plutôt que son dos.
	var entrance := _entrance_near(player.position)
	if not entrance.is_empty():
		rig.face(entrance["normal"])


func get_zoom() -> int:
	return INTERIOR_ZOOM if is_interior else 1


func _physics_process(_delta: float) -> void:
	_check_goto_markers()


# Les quêtes en cours qui attendent Akan à un repère de ce lieu : est-il arrivé ?
func _check_goto_markers() -> void:
	if player == null:
		return
	for quest_id: String in GameState.quests.active_ids():
		var step := GameState.quests.current_step(quest_id)
		var target: String = step.get("target", "")
		if step.get("type") != "GOTO" or not target.begins_with(zone_id + TARGET_SEPARATOR):
			continue
		var at := marker_position(target.get_slice(TARGET_SEPARATOR, 1))
		var offset := Vector2(at.x - player.global_position.x, at.z - player.global_position.z)
		if offset.length() <= GOTO_RADIUS:
			GameState.objective("GOTO", target)


## Position d'un repère (ou du repère par défaut), toujours sur une case libre.
## Un repère peut aussi s'écrire en mètres, « x,z » : pratique pour les captures.
func marker_position(marker: String = DEFAULT_MARKER) -> Vector3:
	var coordinates := marker.split(",")
	var is_point := coordinates.size() == 2 and coordinates[0].is_valid_float()
	if not markers.has(marker) and is_point and coordinates[1].is_valid_float():
		return nearest_free(Vector3(coordinates[0].to_float(), 0.0, coordinates[1].to_float()))
	var wanted: Vector3 = markers.get(marker, markers.get(DEFAULT_MARKER, Vector3.ZERO))
	return nearest_free(wanted)


## Là où poser Akan quand il arrive au repère `marker`.
func spawn_position(marker: String = DEFAULT_MARKER) -> Vector3:
	return marker_position(marker) + Vector3.UP * SPAWN_HEIGHT


## Centre de la case libre la plus proche (recherche en anneaux carrés de plus en plus grands).
func nearest_free(position: Vector3) -> Vector3:
	var nav := geometry.nav_data
	var start := nav.cell_of(position)
	if not nav.is_solid(start):
		return Vector3(position.x, 0.0, position.z)
	var best := Vector3(position.x, 0.0, position.z)
	var best_distance := INF
	for radius: int in range(1, FREE_SEARCH_RADIUS):
		for dx: int in range(-radius, radius + 1):
			for dy: int in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := start + Vector2i(dx, dy)
				if nav.is_solid(cell):
					continue
				var center := nav.center_of(cell)
				var distance := center.distance_squared_to(position)
				if distance < best_distance:
					best_distance = distance
					best = center
		if best_distance < INF:
			break
	return best


# Les lanternes des lampadaires, et les appliques au-dessus des entrées d'immeubles.
func _add_lamp_lights() -> void:
	var lamps := LampLights.new()
	lamps.name = "LampLights"
	lamps.player = player
	lamps.positions = geometry.lamp_positions.duplicate()
	lamps.positions.append_array(_extra_lamps)
	for entrance: Dictionary in geometry.entrances:
		var at: Vector3 = entrance["position"] + entrance["normal"] * ENTRANCE_LIGHT_OFFSET.x
		lamps.positions.append(at + Vector3.UP * ENTRANCE_LIGHT_OFFSET.y)
	add_child(lamps)


# L'entrée d'immeuble la plus proche du point, à moins de ENTRANCE_REACH mètres, ou {}.
func _entrance_near(at: Vector3) -> Dictionary:
	var found := {}
	var best := ENTRANCE_REACH
	for entrance: Dictionary in geometry.entrances:
		var position: Vector3 = entrance["position"]
		if position.distance_to(Vector3(at.x, 0.0, at.z)) < best:
			best = position.distance_to(Vector3(at.x, 0.0, at.z))
			found = entrance
	return found


func _make_geometry() -> ZoneGeometry:
	if definition.is_empty():
		return null
	if is_interior:
		return InteriorBuilder.build(definition, Palette.load_colors())
	var path := GEOMETRY_PATH % zone_id
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	return scene.instantiate()


# Un intérieur tient ses repères de son plan ; une zone extérieure les donne en mètres.
func _read_markers() -> void:
	markers = geometry.markers.duplicate()
	if is_interior:
		return
	var points: Dictionary = definition.get("markers", {})
	for marker: String in points:
		var point: Array = points[marker]
		markers[marker] = Vector3(point[0], 0.0, point[1])


# Le mobilier d'un intérieur est dessiné dans son plan ; celui d'une zone extérieure est
# une liste, chaque élément posé sur un repère.
func _add_props() -> void:
	var placements: Array[Dictionary] = []
	if is_interior:
		placements = InteriorBuilder.prop_placements(definition)
	else:
		for prop: Dictionary in definition.get("props", []):
			var at := marker_position(prop["at"])
			var solid: bool = prop.get("solid", true)
			placements.append(
				{
					"model": prop["model"],
					"yaw": prop.get("yaw", 0.0),
					"solid": solid,
					"position": at
				}
			)
			if solid:
				geometry.nav_data.set_solid(geometry.nav_data.cell_of(at))
	for placement: Dictionary in placements:
		var prop := Prop.create(placement["model"], placement["solid"])
		prop.position = placement["position"]
		prop.rotation_degrees.y = placement["yaw"]
		add_child(prop)
		if placement["model"] == ZoneDressing.LAMP_MODEL:
			_extra_lamps.append(prop.position + prop.basis * ZoneDressing.LAMP_HEAD)


func _add_pickups() -> void:
	for pickup: Dictionary in definition.get("pickups", []):
		var id := "%s:%s" % [zone_id, pickup["id"]]
		if GameState.has_flag(Pickup.TAKEN_FLAG % id):
			continue
		var node := Pickup.create(pickup["item"], int(pickup.get("count", 1)), id)
		node.position = marker_position(pickup["at"])
		add_child(node)


# Un personnage n'est là que si sa condition « if » est vraie à l'arrivée d'Akan.
func _add_npcs() -> void:
	for npc: Dictionary in definition.get("npcs", []):
		if not Conditions.check(npc.get("if", {})):
			continue
		var node := Npc.create(npc)
		node.position = marker_position(npc["at"])
		add_child(node)


## La grille de chemins de la zone, construite au premier besoin et partagée.
func nav_grid() -> NavGrid:
	if _nav_grid == null:
		_nav_grid = NavGrid.new(geometry.nav_data)
	return _nav_grid


func _add_vigiles() -> void:
	for vigile_data: Dictionary in definition.get("vigiles", []):
		if not Conditions.check(vigile_data.get("if", {})):
			continue
		var vigile := Vigile.create(vigile_data)
		vigile.nav = geometry.nav_data
		vigile.grid = nav_grid()
		for marker: String in vigile_data["patrol"]:
			vigile.patrol.append(marker_position(marker))
		vigile.position = vigile.patrol[0] + Vector3.UP * SPAWN_HEIGHT
		add_child(vigile)


func _add_cameras() -> void:
	for camera_data: Dictionary in definition.get("cameras", []):
		if not Conditions.check(camera_data.get("if", {})):
			continue
		var camera := SecurityCamera.create(camera_data)
		camera.nav = geometry.nav_data
		camera.position = marker_position(camera_data["at"])
		add_child(camera)


# Ce qui ne tient pas dans le sac tombe aux pieds d'Akan.
func _on_item_dropped(item_id: String, amount: int) -> void:
	var node := Pickup.create(item_id, amount)
	var at := player.global_position
	node.position = Vector3(at.x, 0.0, at.z)
	add_child(node)


func _add_door(door: Dictionary) -> void:
	var node := Door.new()
	node.name = "Door_%s" % door["at"]
	node.target = door["to"]
	node.prompt = door.get("prompt", "")
	node.knock = door.get("dialogue", [])
	node.position = marker_position(door["at"])
	add_child(node)
