class_name DialogueBalloon
extends Control
## La bulle de dialogue : qui parle, ce qu'il dit, et les réponses d'Akan avec leur ton
## (Calme, Cash, Malin). Pendant un dialogue, le jeu est en pause.
##
## Les dialogues sont des fichiers dialogue/*.dialogue (addon Dialogue Manager) ; ils
## lisent et changent la partie par le vocabulaire de Story.

const DIALOGUE_PATH := "res://dialogue/%s.dialogue"
const TONE_TAG := "ton"
const TONE_KEY := "TONE_%s"
const SPEAKER_KEY := "CHAR_%s"
const WIDTH := 400
const TEXT_LINES := 2
const BOTTOM_MARGIN := 8
const ADVANCE_ACTIONS: Array[StringName] = [&"ui_accept", &"interact"]

var _source := ""
## Dialogues demandés pendant qu'un autre se déroulait : [dialogue, entrée].
var _waiting_list: Array[Array] = []
var _resource: DialogueResource
var _line: DialogueLine
var _story := Story.new()
var _waiting := false
var _speaker := Label.new()
var _text := RichTextLabel.new()
var _responses := VBoxContainer.new()


func _init() -> void:
	hide()
	# Main donne à la bulle la taille de l'écran ; son contenu s'ancre en bas, au milieu.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	rows.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rows.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rows.position.y -= BOTTOM_MARGIN
	rows.custom_minimum_size.x = WIDTH
	add_child(rows)
	_responses.name = "Responses"
	_responses.size_flags_horizontal = Control.SIZE_SHRINK_END
	rows.add_child(_responses)
	var panel := PanelContainer.new()
	rows.add_child(panel)
	var lines := VBoxContainer.new()
	panel.add_child(lines)
	_speaker.name = "Speaker"
	lines.add_child(_speaker)
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(_text)


func _ready() -> void:
	# La bulle continue de vivre pendant la pause qu'elle déclenche.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var line_height := _text.get_theme_font(&"normal_font").get_height(
		_text.get_theme_font_size(&"normal_font_size")
	)
	_text.custom_minimum_size.y = line_height * TEXT_LINES
	EventBus.dialogue_requested.connect(start)


func _unhandled_input(event: InputEvent) -> void:
	if _resource == null:
		return
	for action: StringName in ADVANCE_ACTIONS:
		if event.is_action_pressed(action):
			advance()
			get_viewport().set_input_as_handled()
			return


## Lance le dialogue `dialogue` (un nom de dialogue/, ou un chemin res://) à l'entrée
## `cue`. Si un dialogue est déjà en cours, celui-ci attend son tour.
func start(dialogue: String, cue: String = "") -> void:
	if _resource != null:
		_waiting_list.append([dialogue, cue])
		return
	var path := dialogue if dialogue.begins_with("res://") else DIALOGUE_PATH % dialogue
	if not ResourceLoader.exists(path):
		push_error("Dialogue introuvable : %s" % dialogue)
		return
	_source = dialogue
	_resource = load(path)
	get_tree().paused = true
	_next(cue)


## Passe à la réplique suivante ; sans effet tant qu'une réponse est attendue.
func advance() -> void:
	if _line != null and not _waiting and _allowed_responses().is_empty():
		_next(_line.next_id)


func _next(key: String) -> void:
	_waiting = true
	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(_resource, key, [_story])
	_waiting = false
	if line == null:
		_finish()
		return
	_line = line
	_show_line()


func _show_line() -> void:
	var key := SPEAKER_KEY % _line.character.to_upper()
	_speaker.text = tr(key) if tr(key) != key else _line.character
	_text.text = _line.text
	for old: Node in _responses.get_children():
		_responses.remove_child(old)
		old.queue_free()
	for response: DialogueResponse in _allowed_responses():
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _response_text(response)
		button.pressed.connect(_next.bind(response.next_id))
		_responses.add_child(button)
	if _responses.get_child_count() > 0:
		var first: Button = _responses.get_child(0)
		first.grab_focus()
	show()


func _allowed_responses() -> Array[DialogueResponse]:
	var allowed: Array[DialogueResponse] = []
	if _line != null:
		for response: DialogueResponse in _line.responses:
			if response.is_allowed:
				allowed.append(response)
	return allowed


# « [Calme] Oui. » : le ton d'une réponse est toujours écrit.
func _response_text(response: DialogueResponse) -> String:
	var tone := response.get_tag_value(TONE_TAG)
	if tone.is_empty():
		return response.text
	return "[%s] %s" % [tr(TONE_KEY % tone.to_upper()), response.text]


func _finish() -> void:
	var ended := _source
	_resource = null
	_line = null
	_source = ""
	hide()
	get_tree().paused = false
	EventBus.dialogue_ended.emit(ended)
	if not _waiting_list.is_empty():
		var next: Array = _waiting_list.pop_front()
		start(next[0], next[1])
