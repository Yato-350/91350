class_name Screens
extends Control
## Les écrans qui suspendent le jeu : sac, journal, pause, titre, fin d'acte, crédits,
## confirmation. Ils s'empilent : seul celui du dessus reçoit les entrées et le focus ;
## « annuler » le referme et rend la main à celui d'en dessous. Tant qu'un écran est
## ouvert, l'arbre de scène est en pause et le monde s'arrête.

## Action d'entrée → nom de l'écran qu'elle ouvre et referme.
const ACTIONS := {&"inventory": "Inventory", &"journal": "Journal"}
const PAUSE := "Pause"
const CONFIRM := "Confirm"
const CONFIRM_YES := "yes"

var _stack: Array[Control] = []
var _on_confirmed := Callable()


func _ready() -> void:
	# Cet écran doit continuer de recevoir les entrées pendant la pause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var screens: Dictionary = {
		"Inventory": InventoryScreen.new(),
		"Journal": JournalScreen.new(),
		PAUSE: PauseMenu.new(),
		"Title": TitleMenu.new(),
		"ActEnd": ActEndScreen.new(),
		"Credits": CreditsScreen.new(),
		CONFIRM: ConfirmDialog.new(),
	}
	for screen_name: String in screens:
		var screen: Control = screens[screen_name]
		screen.name = screen_name
		add_child(screen)
		var menu := screen as MenuScreen
		if menu != null:
			menu.chosen.connect(_on_menu_chosen.bind(menu))


# Avant l'interface : Tab et Échap y servent aussi à déplacer le focus.
func _input(event: InputEvent) -> void:
	var top := _top()
	if top != null:
		var cancel := event.is_action_pressed(&"ui_cancel") and _cancellable(top)
		if cancel or (event.is_action_pressed(&"pause") and top.name == PAUSE):
			EventBus.sound_requested.emit(&"ui_retour")
			close()
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed(&"pause"):
		open(PAUSE)
		get_viewport().set_input_as_handled()
		return
	for action: StringName in ACTIONS:
		if not event.is_action_pressed(action):
			continue
		if top == null:
			open(ACTIONS[action])
		elif top != null and top.name == ACTIONS[action]:
			close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return not _stack.is_empty()


## Le nom de l'écran du dessus, ou "".
func top_name() -> String:
	var top := _top()
	return String(top.name) if top != null else ""


## Ouvre l'écran nommé par-dessus les autres. Sans effet s'il est inconnu, déjà ouvert, ou
## si le jeu est suspendu par autre chose (un dialogue).
func open(screen_name: String) -> void:
	var screen := get_node_or_null(screen_name) as Control
	if screen == null or _stack.has(screen):
		return
	if _stack.is_empty() and get_tree().paused:
		return
	if not _stack.is_empty():
		_cover(_top(), true)
	_stack.append(screen)
	screen.call(&"open")
	get_tree().paused = true


## Referme l'écran du dessus ; celui d'en dessous reprend le focus.
func close() -> void:
	if _stack.is_empty():
		return
	var screen: Control = _stack.pop_back()
	screen.call(&"close")
	if _stack.is_empty():
		get_tree().paused = false
		return
	var below := _top()
	_cover(below, false)
	if below.has_method(&"focus"):
		below.call(&"focus")


func close_all() -> void:
	while not _stack.is_empty():
		close()


## Pose une question (clé de traduction) ; « oui » referme la question puis appelle
## `on_yes`, « non » la referme seulement.
func confirm(question: String, on_yes: Callable) -> void:
	var dialog := get_node(CONFIRM) as ConfirmDialog
	dialog.question = question
	_on_confirmed = on_yes
	open(CONFIRM)


func _on_menu_chosen(choice: String, menu: MenuScreen) -> void:
	if menu.name == CONFIRM:
		close()
		if choice == CONFIRM_YES and _on_confirmed.is_valid():
			_on_confirmed.call()
	elif choice == MenuScreen.BACK:
		close()


func _top() -> Control:
	return _stack.back() if not _stack.is_empty() else null


func _cancellable(screen: Control) -> bool:
	var menu := screen as MenuScreen
	return menu == null or menu.cancellable


# Un écran recouvert ne prend plus ni le focus ni la souris.
func _cover(screen: Control, covered: bool) -> void:
	screen.focus_behavior_recursive = (
		Control.FOCUS_BEHAVIOR_DISABLED if covered else Control.FOCUS_BEHAVIOR_INHERITED
	)
	screen.mouse_behavior_recursive = (
		Control.MOUSE_BEHAVIOR_DISABLED if covered else Control.MOUSE_BEHAVIOR_INHERITED
	)
