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
## Ce qui n'est là que sous condition est relu à ce rythme (s), pour les horaires.
const CONDITION_REFRESH_SECONDS := 1.0

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
## Ce qui n'est là que sous condition : {"if": condition, "make": fabrique, "node": nœud}.
var _conditional: Array[Dictionary] = []
var _refresh_left := CONDITION_REFRESH_SECONDS


## Rend le lieu demandé, ou null (erreur journalisée) s'il n'existe pas.
## `ref` peut préciser un repère d'arrivée : « grigny2@gare ».
static func create(ref: String) -> Zone:
	var id := ref.get_slice(MARKER_SEPARATOR, 0)
	var definition := DataRegistry.entry("zones", id)
	var interior := definition.is_empty()
	if interior:
		definition = DataRegistry.entry("interiors", id)
	var zone := from_definition(id, definition, interior)
	if zone != null and ref.contains(MARKER_SEPARATOR):
		zone.arrival = ref.get_slice(MARKER_SEPARATOR, 1)
	return zone


## Rend le lieu décrit par `definition` (une fiche de data/zones/ ou, si `interior`, de
## data/interiors/), ou null (erreur journalisée) si sa géométrie manque.
static func from_definition(id: String, place: Dictionary, interior: bool) -> Zone:
	var zone := Zone.new()
	zone.name = id.capitalize().replace(" ", "")
	zone.zone_id = id
	zone.definition = place
	zone.is_interior = interior
	zone.territory_id = place.get("territory", "") if interior else id
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
	# Un toit est « à l'air libre » : il vit au rythme du jour et de la nuit.
	if is_interior and not definition.get("open_air", false):
		sky.use_interior_light(Palette.load_colors()[INTERIOR_BACKGROUND])
	for door: Dictionary in definition.get("doors", []):
		_place(door.get("if", {}), _make_door.bind(door))
	_add_props()
	_add_pickups()
	_add_spots()
	for npc: Dictionary in definition.get("npcs", []):
		_place(npc.get("if", {}), _make_npc.bind(npc))
	for camera: Dictionary in definition.get("cameras", []):
		_place(camera.get("if", {}), _make_camera.bind(camera))
	for vigile: Dictionary in definition.get("vigiles", []):
		_place(vigile.get("if", {}), _make_vigile.bind(vigile, _patrol_of(vigile)))
	EventBus.item_dropped.connect(_on_item_dropped)
	for changed: Signal in [
		EventBus.flag_changed,
		EventBus.quest_progressed,
		EventBus.zone_liberated,
		EventBus.inventory_changed
	]:
		changed.connect(refresh_conditions.unbind(1))
	player = PLAYER_SCENE.instantiate()
	player.position = spawn_position(arrival)
	add_child(player)
	_check_defense()
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


## La musique du lieu : celle de la maison chez soi, ailleurs celle de sa couleur.
func music() -> StringName:
	if definition.get("home", false):
		return &"maison"
	return &"libre" if saturation() >= Territory.FREE_SATURATION else &"regime"


## L'ambiance du lieu : la rumeur de la ville dehors (et sur un toit), rien dedans.
func ambience() -> StringName:
	return &"ville" if not is_interior or definition.get("open_air", false) else &""


## Saturation du rendu ici : gris dans le territoire du régime, couleur une fois libre ;
## un logement (« home ») garde toujours ses couleurs : chez soi, le régime n'entre pas.
func saturation() -> float:
	if definition.get("home", false):
		return Territory.FREE_SATURATION
	return GameState.territory.saturation(territory_id)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = CONDITION_REFRESH_SECONDS
		refresh_conditions()


func _physics_process(_delta: float) -> void:
	_check_goto_markers()


## Relit les conditions de présence : qui arrive, qui s'en va ; et si une défense commence.
func refresh_conditions() -> void:
	for entry: Dictionary in _conditional:
		_refresh_entry(entry)
	_check_defense()


# Ajoute ce que fabrique `make`, tout de suite s'il n'y a pas de condition ; sinon chaque
# fois que la condition devient vraie (et le retire quand elle redevient fausse).
func _place(condition: Dictionary, make: Callable) -> void:
	if condition.is_empty():
		add_child(make.call())
		return
	var entry := {"if": condition, "make": make, "node": null}
	_conditional.append(entry)
	_refresh_entry(entry)


func _refresh_entry(entry: Dictionary) -> void:
	var wanted := Conditions.check(entry["if"])
	var node: Variant = entry["node"]
	var present := is_instance_valid(node) and not (node as Node).is_queued_for_deletion()
	if wanted and not present:
		var made: Node = entry["make"].call()
		add_child(made)
		entry["node"] = made
	elif not wanted and present:
		(node as Node).queue_free()
		entry["node"] = null


# Une étape « DEFEND » qui porte sur ce lieu : les Vigiles descendent (une seule défense
# par quête à la fois).
func _check_defense() -> void:
	if player == null:
		return
	for quest_id: String in GameState.quests.active_ids():
		var step := GameState.quests.current_step(quest_id)
		if step.get("type") != "DEFEND" or step.get("target") != zone_id:
			continue
		var node_name := "Defense%s" % quest_id.to_pascal_case()
		if has_node(node_name):
			continue
		var defense := DefenseWaves.new()
		defense.name = node_name
		defense.zone = self
		defense.quest_id = quest_id
		defense.step = step
		add_child(defense)


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
			var at := _prop_position(prop)
			var solid: bool = prop.get("solid", true)
			(
				placements
				. append(
					{
						"model": prop["model"],
						"yaw": prop.get("yaw", 0.0),
						"solid": solid,
						"position": at,
						"if": prop.get("if", {}),
					}
				)
			)
			# Un décor qui va et vient ne bouche pas la grille des chemins.
			if solid and not prop.has("if"):
				geometry.nav_data.set_solid(geometry.nav_data.cell_of(at))
	for placement: Dictionary in placements:
		var condition: Dictionary = placement.get("if", {})
		_place(condition, _make_prop.bind(placement))
		if placement["model"] == ZoneDressing.LAMP_MODEL and condition.is_empty():
			var basis := Basis.from_euler(Vector3(0.0, deg_to_rad(placement["yaw"]), 0.0))
			_extra_lamps.append(placement["position"] + basis * ZoneDressing.LAMP_HEAD)


# Un décor « exact » se pose au centimètre près (une fresque plaquée sur un mur) ; les
# autres, sur la case libre la plus proche de leur repère.
func _prop_position(prop: Dictionary) -> Vector3:
	var at: String = prop["at"]
	var coordinates := at.split(",")
	if prop.get("exact", false) and coordinates.size() == 2:
		return Vector3(coordinates[0].to_float(), 0.0, coordinates[1].to_float())
	return marker_position(at)


func _make_prop(placement: Dictionary) -> Prop:
	var prop := Prop.create(placement["model"], placement["solid"])
	prop.position = placement["position"]
	prop.rotation_degrees.y = placement["yaw"]
	return prop


func _add_pickups() -> void:
	for pickup: Dictionary in definition.get("pickups", []):
		var id := "%s:%s" % [zone_id, pickup["id"]]
		if GameState.has_flag(Pickup.TAKEN_FLAG % id):
			continue
		var node := Pickup.create(pickup["item"], int(pickup.get("count", 1)), id)
		node.position = marker_position(pickup["at"])
		add_child(node)


func _add_spots() -> void:
	for spot_data: Dictionary in definition.get("spots", []):
		var spot := Spot.create(spot_data)
		spot.position = marker_position(spot_data["at"])
		add_child(spot)


# Un personnage n'est là que tant que sa condition « if » est vraie.
func _make_npc(npc: Dictionary) -> Npc:
	var node := Npc.create(npc)
	node.position = marker_position(npc["at"])
	return node


## La grille de chemins de la zone, construite au premier besoin et partagée.
func nav_grid() -> NavGrid:
	if _nav_grid == null:
		_nav_grid = NavGrid.new(geometry.nav_data)
	return _nav_grid


## Pose un Vigile ({"id", "character"}) sur sa ronde, avec la grille du lieu.
func spawn_vigile(data: Dictionary, patrol: Array[Vector3]) -> Vigile:
	var vigile := _make_vigile(data, patrol)
	add_child(vigile)
	return vigile


func _make_vigile(data: Dictionary, patrol: Array[Vector3]) -> Vigile:
	var vigile := Vigile.create(data)
	vigile.nav = geometry.nav_data
	vigile.grid = nav_grid()
	vigile.patrol = patrol.duplicate()
	vigile.position = patrol[0] + Vector3.UP * SPAWN_HEIGHT
	return vigile


func _patrol_of(vigile: Dictionary) -> Array[Vector3]:
	var patrol: Array[Vector3] = []
	for marker: String in vigile["patrol"]:
		patrol.append(marker_position(marker))
	return patrol


func _make_camera(camera_data: Dictionary) -> SecurityCamera:
	var camera := SecurityCamera.create(camera_data)
	camera.nav = geometry.nav_data
	camera.position = marker_position(camera_data["at"])
	return camera


# Ce qui ne tient pas dans le sac tombe aux pieds d'Akan.
func _on_item_dropped(item_id: String, amount: int) -> void:
	var node := Pickup.create(item_id, amount)
	var at := player.global_position
	node.position = Vector3(at.x, 0.0, at.z)
	add_child(node)


func _make_door(door: Dictionary) -> Door:
	var node := Door.new()
	node.name = "Door_%s" % door["at"]
	node.target = door["to"]
	node.prompt = door.get("prompt", "")
	node.knock = door.get("dialogue", [])
	node.position = marker_position(door["at"])
	return node
