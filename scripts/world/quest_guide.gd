class_name QuestGuide
extends Node3D
## Le repère de quête : un losange qui flotte au-dessus de la cible de l'objectif en
## cours — ou, si la cible est dans un autre lieu, au-dessus de la porte qui y mène.
## On guide par un signe visible, pas par des murs.

const MODEL := "props/repere"
const HEIGHT := 2.4
const BOB_HEIGHT := 0.15
const BOB_SPEED := 3.0
const SPIN_SPEED := 1.5
const REFRESH_SECONDS := 0.25
const TARGET_SEPARATOR := ":"

var zone: Zone

var _beacon: Node3D
var _target := Vector3.INF
var _age := REFRESH_SECONDS
var _time := 0.0


func _ready() -> void:
	# Le repère reste lisible même quand un bâtiment le cache : jamais découpé.
	_beacon = VoxelModel.instantiate(MODEL, VoxelModel.CHARACTER_MATERIAL)
	if _beacon != null:
		add_child(_beacon)
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	_age += delta
	if _age >= REFRESH_SECONDS:
		_age = 0.0
		_refresh()
	if _beacon != null and _beacon.visible:
		_beacon.position = beacon_position()
		_beacon.rotation.y = _time * SPIN_SPEED


func beacon_visible() -> bool:
	return _target.is_finite()


## Où flotte le repère (au-dessus de la cible), ou Vector3.INF s'il n'y en a pas.
func beacon_position() -> Vector3:
	if not _target.is_finite():
		return Vector3.INF
	return _target + Vector3.UP * (HEIGHT + sin(_time * BOB_SPEED) * BOB_HEIGHT)


func _refresh() -> void:
	_target = target_position()
	if _beacon != null:
		_beacon.visible = _target.is_finite()


## Position (au sol) de la cible de la quête suivie, dans ce lieu ; Vector3.INF si aucune.
func target_position() -> Vector3:
	var quest := GameState.tracked_quest()
	if quest.is_empty() or zone == null:
		return Vector3.INF
	var step := GameState.quests.current_step(quest)
	var type: String = step.get("type", "")
	var target: String = step.get("target", "")
	if type in ["TALK", "DELIVER"]:
		var npc := _npc(target)
		if npc != null:
			return npc.global_position
	var where: String = target if type == "GOTO" else step.get("where", "")
	if where.is_empty():
		return Vector3.INF
	var place := where.get_slice(TARGET_SEPARATOR, 0)
	if place == zone.zone_id:
		if where.contains(TARGET_SEPARATOR):
			return zone.marker_position(where.get_slice(TARGET_SEPARATOR, 1))
		return Vector3.INF
	return _door_towards(place)


func _npc(character: String) -> Npc:
	for child: Node in zone.get_children():
		var npc := child as Npc
		if npc != null and npc.character_id == character:
			return npc
	return null


# La porte de ce lieu par laquelle passe le plus court chemin vers `place`.
func _door_towards(place: String) -> Vector3:
	var next := PlaceGraph.next_place(zone.zone_id, place)
	for child: Node in zone.get_children():
		var door := child as Door
		if door != null and door.target.get_slice(GameState.MARKER_SEPARATOR, 0) == next:
			return door.global_position
	return Vector3.INF
