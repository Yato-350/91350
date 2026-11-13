class_name Screens
extends Control
## Les écrans qui suspendent le jeu (sac, journal, pause). Un seul à la fois ; tant que
## l'un d'eux est ouvert, l'arbre de scène est en pause et le monde s'arrête.

## Action d'entrée → nom de l'écran qu'elle ouvre et referme.
const ACTIONS := {&"inventory": "Inventory", &"journal": "Journal"}

var _current: Control


func _ready() -> void:
	# Cet écran doit continuer de recevoir les entrées pendant la pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inventory := InventoryScreen.new()
	inventory.name = "Inventory"
	add_child(inventory)
	var journal := JournalScreen.new()
	journal.name = "Journal"
	add_child(journal)


# Avant l'interface : Tab et Échap y servent aussi à déplacer le focus.
func _input(event: InputEvent) -> void:
	if _current != null and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	for action: StringName in ACTIONS:
		if not event.is_action_pressed(action):
			continue
		if _current == null:
			open(ACTIONS[action])
		elif _current.name == ACTIONS[action]:
			close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _current != null


## Ouvre l'écran nommé, sauf si un écran est déjà ouvert ou si le jeu est déjà suspendu
## par autre chose (un dialogue).
func open(screen_name: String) -> void:
	var screen := get_node_or_null(screen_name) as Control
	if screen == null or _current != null or get_tree().paused:
		return
	_current = screen
	screen.call(&"open")
	get_tree().paused = true


func close() -> void:
	if _current == null:
		return
	_current.call(&"close")
	_current = null
	get_tree().paused = false
