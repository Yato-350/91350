class_name Npc
extends Interactable
## Un habitant : son modèle voxel, un corps qui barre le passage, et de quoi parler.
## Sans dialogue, il fait seulement partie du décor.

const BODY_RADIUS := 0.3
const BODY_HEIGHT := 1.7
## Entrée jouée par défaut dans son fichier de dialogue.
const DEFAULT_CUE := "start"
## En deçà de cette distance, l'habitant tourne la tête vers Akan.
const LOOK_DISTANCE := 4.0
## Hauteur des yeux d'Akan, que l'on regarde.
const EYE_HEIGHT := 1.5

var character_id := ""
## Nom du fichier de dialogue/ et entrée à y jouer.
var dialogue := ""
var cue := ""
var visual := CharacterVisual.new()


## Crée le personnage décrit par une entrée « npcs » d'un lieu :
## {"id", "character", "dialogue", "cue", "yaw"}. Sa condition de présence (« if »)
## est l'affaire du lieu, qui le fait venir et partir.
static func create(definition: Dictionary) -> Npc:
	var npc := Npc.new()
	var id: String = definition.get("id", definition.get("character", ""))
	npc.name = id.to_pascal_case()
	npc.character_id = definition.get("character", "")
	npc.dialogue = definition.get("dialogue", "")
	npc.cue = definition.get("cue", DEFAULT_CUE)
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


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player != null and player.global_position.distance_to(global_position) < LOOK_DISTANCE:
		visual.look_at_point(player.global_position + Vector3.UP * EYE_HEIGHT)
	else:
		visual.stop_looking()


func _on_interacted(player: Player) -> void:
	if player != null:
		var towards := player.global_position - global_position
		visual.rotation.y = atan2(-towards.x, -towards.z)
	# Le jeu est en pause pendant un dialogue : celui qui parle continue de bouger.
	visual.talking = true
	visual.process_mode = Node.PROCESS_MODE_ALWAYS
	if not EventBus.dialogue_ended.is_connected(_on_dialogue_ended):
		EventBus.dialogue_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)
	EventBus.dialogue_requested.emit(dialogue, cue)


## Vrai pendant qu'il parle avec Akan : s'il doit partir, il finit d'abord sa phrase.
func is_talking() -> bool:
	return visual.talking


# Une conversation menée à son terme vaut « parler à » ce personnage.
func _on_dialogue_ended(_dialogue: String) -> void:
	visual.talking = false
	visual.process_mode = Node.PROCESS_MODE_INHERIT
	GameState.objective("TALK", character_id)
