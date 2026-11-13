class_name Interactable
extends Node3D
## Un point du monde avec lequel Akan peut interagir : une porte, un objet, un voisin.
## Akan vise le plus proche à sa portée ; la commande « interact » le déclenche.

signal interacted(player: Player)

const GROUP := &"interactable"

## Clé de traduction du verbe affiché (« Entrer », « Parler »).
@export var prompt := ""
@export var enabled := true
## Distance en mètres jusqu'à laquelle Akan peut interagir.
@export var radius := 1.6


func _init() -> void:
	add_to_group(GROUP)


func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)
