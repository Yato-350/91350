class_name Npc
extends Interactable
## Un habitant : son modèle voxel, un corps qui barre le passage, et de quoi parler.
## Sans dialogue, il fait seulement partie du décor.

const BODY_RADIUS := 0.3
const BODY_HEIGHT := 1.7

var character_id := ""
## Nom du fichier de dialogue/ et entrée à y jouer.
var dialogue := ""
var cue := ""
var visual := CharacterVisual.new()


## Crée le personnage décrit par une entrée « npcs » d'un lieu :
## {"id", "character", "dialogue", "cue", "yaw"}.
static func create(definition: Dictionary) -> Npc:
	var npc := Npc.new()
	var id: String = definition.get("id", definition.get("character", ""))
	npc.name = id.to_pascal_case()
	npc.character_id = definition.get("character", "")
	npc.dialogue = definition.get("dialogue", "")
	npc.cue = definition.get("cue", "")
	npc.prompt = "PROMPT_PARLER"
	npc.enabled = not npc.dialogue.is_empty()
	npc.visual.name = "Visual"
	npc.visual.character_id = npc.character_id
	npc.visual.rotation_degrees.y = definition.get("yaw", 0.0)
	npc.add_child(npc.visual)
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	MeshKit.add_body(npc, "Body", capsule, Vector3.UP * BODY_HEIGHT / 2.0)
	npc.interacted.connect(npc._on_interacted)
	return npc


func _on_interacted(player: Player) -> void:
	if player != null:
		var towards := player.global_position - global_position
		visual.rotation.y = atan2(-towards.x, -towards.z)
	EventBus.dialogue_requested.emit(dialogue, cue)
