class_name Zone
extends Node3D
## Une zone extérieure du jeu : sa géométrie (cuite depuis OpenStreetMap), son ciel,
## le joueur et sa caméra. Le contenu de jeu vient de data/zones/<zone>.json.

const DEFINITION_PATH := "res://data/zones/%s.json"
const GEOMETRY_PATH := "res://scenes/zones/generated/%s.scn"
const SKY_SCENE := preload("res://scenes/world/sky.tscn")
const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const CAMERA_RIG_SCENE := preload("res://scenes/actors/camera_rig.tscn")
const DEFAULT_SPAWN := "default"
const SPAWN_SEPARATOR := "@"
## Hauteur d'apparition au-dessus du sol : le joueur se pose tout seul.
const SPAWN_HEIGHT := 0.1
## Rayon maximal (en cases) de la recherche d'une case libre.
const FREE_SEARCH_RADIUS := 40

var zone_id := ""
## Point d'apparition du joueur à l'entrée dans la zone.
var spawn := DEFAULT_SPAWN
var definition := {}
var geometry: ZoneGeometry
var player: Player


## Rend la zone demandée, ou null (erreur journalisée) si elle n'existe pas.
## `id` peut préciser un point d'apparition : « grigny2@gare ».
static func create(id: String) -> Zone:
	var spawn_name := DEFAULT_SPAWN
	if id.contains(SPAWN_SEPARATOR):
		spawn_name = id.get_slice(SPAWN_SEPARATOR, 1)
		id = id.get_slice(SPAWN_SEPARATOR, 0)
	var definition_path := DEFINITION_PATH % id
	var geometry_path := GEOMETRY_PATH % id
	if not FileAccess.file_exists(definition_path) or not ResourceLoader.exists(geometry_path):
		push_error("Zone inconnue : %s" % id)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(definition_path))
	if not data is Dictionary:
		push_error("Définition de zone illisible : %s" % id)
		return null
	var zone := Zone.new()
	zone.name = id.capitalize().replace(" ", "")
	zone.zone_id = id
	zone.spawn = spawn_name
	zone.definition = data
	var geometry_scene: PackedScene = load(geometry_path)
	zone.geometry = geometry_scene.instantiate()
	return zone


func _ready() -> void:
	add_child(geometry)
	add_child(SKY_SCENE.instantiate())
	player = PLAYER_SCENE.instantiate()
	player.position = spawn_position(spawn)
	add_child(player)
	var rig: CameraRig = CAMERA_RIG_SCENE.instantiate()
	rig.target = player
	add_child(rig)


## Position d'apparition nommée (ou celle par défaut), toujours sur une case libre.
func spawn_position(spawn_name: String = DEFAULT_SPAWN) -> Vector3:
	var spawns: Dictionary = definition.get("spawns", {})
	var raw: Variant = spawns.get(spawn_name, spawns.get(DEFAULT_SPAWN))
	var wanted := Vector3.ZERO
	if raw is Array and raw.size() == 2:
		wanted = Vector3(raw[0], 0.0, raw[1])
	return nearest_free(wanted) + Vector3.UP * SPAWN_HEIGHT


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
