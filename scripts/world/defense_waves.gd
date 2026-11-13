class_name DefenseWaves
extends Node
## Défendre un lieu (une étape « DEFEND ») : les Vigiles descendent par vagues, depuis un
## repère du lieu ; chacun mis hors d'état compte pour l'étape. La vague suivante vient
## quand la précédente est à terre. Revenir dans le lieu reprend où l'on en était.
##
## L'étape porte : "count" (Vigiles à mettre hors d'état), "waves" (taille de chaque
## vague, dans l'ordre), "spawn" (repère d'arrivée), "enemy" (personnage des Vigiles).

## Les Vigiles d'une même vague arrivent côte à côte, à cet écart (m).
const SPACING := 0.9
const DEFAULT_ENEMY := "vigile"
const ID_FORMAT := "%s_%d"

var zone: Zone
var quest_id := ""
var step: Dictionary

var _wave := 0
var _spawned := 0
## Les Vigiles de la vague en cours encore debout.
var _standing: Array[String] = []


func _ready() -> void:
	EventBus.enemy_knocked_out.connect(_on_enemy_knocked_out)
	# Les vagues déjà tombées (avant une arrestation, une sortie) ne reviennent pas.
	var waves: Array = step.get("waves", [])
	var done := GameState.quests.progress(quest_id)
	while _wave < waves.size() and done >= int(waves[_wave]):
		done -= int(waves[_wave])
		_wave += 1
	if _wave < waves.size():
		_spawn(int(waves[_wave]) - done)


func _spawn(amount: int) -> void:
	var at := zone.marker_position(step.get("spawn", Zone.DEFAULT_MARKER))
	var target := zone.player.global_position if zone.player != null else at
	var side := (target - at).cross(Vector3.UP).normalized()
	for index: int in amount:
		_spawned += 1
		var id := ID_FORMAT % [quest_id, _spawned]
		var offset := side * SPACING * (index - (amount - 1) / 2.0)
		var patrol: Array[Vector3] = [zone.nearest_free(at + offset)]
		var data := {"id": id, "character": step.get("enemy", DEFAULT_ENEMY)}
		var vigile := zone.spawn_vigile(data, patrol)
		vigile.alert(target)
		_standing.append(id)


func _on_enemy_knocked_out(enemy_id: String) -> void:
	if not _standing.has(enemy_id):
		return
	_standing.erase(enemy_id)
	GameState.objective("DEFEND", step.get("target", ""))
	if not _standing.is_empty() or not GameState.quests.is_step(quest_id, step["id"]):
		return
	var waves: Array = step.get("waves", [])
	_wave += 1
	if _wave < waves.size():
		_spawn(int(waves[_wave]))
