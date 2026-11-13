class_name QuestLog
extends RefCounted
## Le journal de quêtes : quelles quêtes sont en cours, à quelle étape.
##
## Une quête est une suite d'étapes ; chaque étape attend un objectif (type, cible,
## nombre). Le jeu signale ce qui se passe avec notify() ; le journal avance tout seul.
## Une étape peut proposer des embranchements : un autre objectif qui mène ailleurs.

signal quest_started(quest_id: String)
signal step_completed(quest_id: String, step_id: String)
signal quest_completed(quest_id: String)
## L'étape en cours a changé, ou son compteur a bougé.
signal progressed(quest_id: String)

const ACTIVE := "active"
const DONE := "done"

var _definitions: Dictionary
## quête → {"state": String, "step": String, "progress": int}, dans l'ordre de départ.
var _states := {}


func _init(definitions: Dictionary) -> void:
	_definitions = definitions


func start(quest_id: String) -> bool:
	if _states.has(quest_id) or _steps(quest_id).is_empty():
		return false
	_states[quest_id] = {"state": ACTIVE, "step": _steps(quest_id)[0]["id"], "progress": 0}
	quest_started.emit(quest_id)
	progressed.emit(quest_id)
	return true


## La fiche de la quête, telle que le journal l'a reçue.
func definition(quest_id: String) -> Dictionary:
	return _definitions.get(quest_id, {})


func is_active(quest_id: String) -> bool:
	return _state(quest_id).get("state") == ACTIVE


func is_done(quest_id: String) -> bool:
	return _state(quest_id).get("state") == DONE


func is_step(quest_id: String, step_id: String) -> bool:
	return is_active(quest_id) and _state(quest_id)["step"] == step_id


func active_ids() -> Array[String]:
	var ids: Array[String] = []
	for quest_id: String in _states:
		if is_active(quest_id):
			ids.append(quest_id)
	return ids


## La quête dont on suit l'objectif : la dernière lancée parmi celles en cours, ou "".
func tracked_id() -> String:
	var active := active_ids()
	return active[active.size() - 1] if not active.is_empty() else ""


## Le texte (clé de traduction) de l'objectif en cours de la quête suivie, ou "".
func tracked_text() -> String:
	var quest := tracked_id()
	return current_step(quest).get("text", "") if not quest.is_empty() else ""


## La fiche de l'étape en cours, ou {} si la quête n'est pas active.
func current_step(quest_id: String) -> Dictionary:
	if not is_active(quest_id):
		return {}
	return _find_step(quest_id, _state(quest_id)["step"])


func progress(quest_id: String) -> int:
	return _state(quest_id).get("progress", 0)


## Le jeu signale un événement (« TALK », « daronne ») ; chaque quête active en profite.
func notify(type: String, target: String, amount: int = 1) -> void:
	for quest_id: String in active_ids():
		var step := current_step(quest_id)
		if step.get("type") == type and step.get("target") == target:
			_count(quest_id, step, amount)
			continue
		for branch: Dictionary in step.get("branches", []):
			if branch.get("type") == type and branch.get("target") == target:
				step_completed.emit(quest_id, step["id"])
				_enter(quest_id, branch.get("goto", ""))
				break


func to_dict() -> Dictionary:
	return _states.duplicate(true)


## Ne relit que les quêtes connues ; une étape inconnue ramène au début de la quête.
func from_dict(saved: Dictionary) -> void:
	_states.clear()
	for quest_id: Variant in saved:
		if not quest_id is String or _steps(quest_id).is_empty():
			continue
		var entry := SaveCodec.table(saved, quest_id)
		var state := SaveCodec.text(entry, "state", ACTIVE)
		var step_id := SaveCodec.text(entry, "step", "")
		var known := not _find_step(quest_id, step_id).is_empty()
		_states[quest_id] = {
			"state": DONE if state == DONE else ACTIVE,
			"step": step_id if known else _steps(quest_id)[0]["id"],
			"progress": int(SaveCodec.number(entry, "progress", 0.0)) if known else 0,
		}
		progressed.emit(quest_id)


func _count(quest_id: String, step: Dictionary, amount: int) -> void:
	var state := _state(quest_id)
	state["progress"] = progress(quest_id) + amount
	if progress(quest_id) < int(step.get("count", 1)):
		progressed.emit(quest_id)
		return
	step_completed.emit(quest_id, step["id"])
	if step.get("end", false):
		_finish(quest_id)
		return
	var steps := _steps(quest_id)
	var index := steps.find(step)
	var following: String = steps[index + 1]["id"] if index + 1 < steps.size() else ""
	_enter(quest_id, step.get("next", following))


# Passe à l'étape `step_id` ; une étape absente ou vide termine la quête.
func _enter(quest_id: String, step_id: String) -> void:
	if _find_step(quest_id, step_id).is_empty():
		_finish(quest_id)
		return
	var state := _state(quest_id)
	state["step"] = step_id
	state["progress"] = 0
	progressed.emit(quest_id)


func _finish(quest_id: String) -> void:
	var state := _state(quest_id)
	state["state"] = DONE
	state["progress"] = 0
	quest_completed.emit(quest_id)
	progressed.emit(quest_id)


func _state(quest_id: String) -> Dictionary:
	return _states.get(quest_id, {})


func _steps(quest_id: String) -> Array:
	var quest: Dictionary = _definitions.get(quest_id, {})
	return quest.get("steps", [])


func _find_step(quest_id: String, step_id: String) -> Dictionary:
	for step: Dictionary in _steps(quest_id):
		if step.get("id") == step_id:
			return step
	return {}
