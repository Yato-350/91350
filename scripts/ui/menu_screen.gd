class_name MenuScreen
extends PanelContainer
## Un écran de menu : un titre, du texte, une colonne de boutons. Son contenu est refait à
## chaque ouverture ; un bouton a toujours le focus, au clavier comme à la manette, et
## « chosen » dit lequel a été pressé (par son nom : « new_game », « save »…).

signal chosen(choice: String)

const WIDTH := 260
const SPACING := 4
## Le choix « back » referme l'écran (voir Screens).
const BACK := "back"

## Vrai si « annuler » referme l'écran (faux pour l'écran titre).
var cancellable := true

var _rows := VBoxContainer.new()
var _buttons: VBoxContainer


func _init() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size.x = WIDTH
	_rows.add_theme_constant_override(&"separation", SPACING)
	add_child(_rows)


## Refait le contenu (build), montre l'écran et donne le focus au premier bouton actif.
func open() -> void:
	for old: Node in _rows.get_children():
		_rows.remove_child(old)
		old.queue_free()
	_buttons = null
	build()
	show()
	focus()


func close() -> void:
	hide()


## Rend le focus au premier bouton actif : à l'ouverture, et quand l'écran du dessus se
## referme.
func focus() -> void:
	if _buttons == null:
		return
	for child: Node in _buttons.get_children():
		var button := child as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return


## À redéfinir : remplit l'écran avec add_title, add_text et add_button.
func build() -> void:
	pass


func add_title(key: String) -> Label:
	var label := add_text(tr(key))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Ajoute un élément quelconque (un texte défilant, une image) à sa place dans l'écran.
func add_control(control: Control) -> void:
	_rows.add_child(control)


func add_text(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - SPACING * 4
	_rows.add_child(label)
	return label


## Ajoute un bouton nommé `id` ; les boutons se suivent en colonne, à l'endroit du premier.
func add_button(id: String, key: String, enabled: bool = true) -> Button:
	if _buttons == null:
		_buttons = VBoxContainer.new()
		_buttons.name = "Buttons"
		_buttons.add_theme_constant_override(&"separation", SPACING / 2)
		_rows.add_child(_buttons)
	var button := Button.new()
	button.name = id
	button.text = tr(key)
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(chosen.emit.bind(id))
	button.pressed.connect(EventBus.sound_requested.emit.bind(&"ui_valide"))
	button.focus_entered.connect(EventBus.sound_requested.emit.bind(&"ui_survol"))
	_buttons.add_child(button)
	return button
