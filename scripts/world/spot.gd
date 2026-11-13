class_name Spot
extends Interactable
## Un point d'action posé par les données d'un lieu : le lit d'Akan, un mur à taguer, un
## boîtier à saboter. Interagir joue un dialogue, et c'est lui qui décide de ce qui se
## passe ; un geste interdit rend Akan suspect aux yeux de qui le voit.

## Le point se réévalue (heures, drapeaux) à ce rythme, en secondes.
const REFRESH_SECONDS := 0.5

var spot_id := ""
## [fichier, entrée] du dialogue joué.
var dialogue: Array = []
## Condition (comme le « if » des personnages) pour que le geste soit possible.
var condition := {}
## Vrai pour un geste interdit (tag, sabotage).
var offence := false

var _refresh_left := 0.0


## Crée le point décrit par une entrée « spots » d'un lieu :
## {"id", "at", "prompt", "dialogue": [fichier, entrée], "if", "offence"}.
static func create(definition: Dictionary) -> Spot:
	var spot := Spot.new()
	spot.spot_id = definition["id"]
	spot.name = "Spot" + spot.spot_id.to_pascal_case()
	spot.prompt = definition.get("prompt", "")
	spot.dialogue = definition.get("dialogue", [])
	spot.condition = definition.get("if", {})
	spot.offence = definition.get("offence", false)
	spot.interacted.connect(spot._on_interacted)
	spot.refresh()
	return spot


## Relit la condition : le geste est-il possible maintenant ?
func refresh() -> void:
	enabled = Conditions.check(condition)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_SECONDS
		refresh()


func _on_interacted(_player: Player) -> void:
	if offence:
		GameState.commit_offence()
	if dialogue.size() == 2:
		EventBus.dialogue_requested.emit(dialogue[0], dialogue[1])
