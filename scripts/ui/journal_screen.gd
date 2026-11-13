class_name JournalScreen
extends PanelContainer
## Le journal : les quêtes en cours (nom, résumé, objectif) et celles déjà menées à bien.

const WIDTH := 420
const SPACING := 4
const DONE_COLOR := "beton_4"

var _list := VBoxContainer.new()


func _init() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size.x = WIDTH
	_list.add_theme_constant_override(&"separation", SPACING)
	add_child(_list)


func open() -> void:
	_refresh()
	show()


func close() -> void:
	hide()


func _refresh() -> void:
	for old: Node in _list.get_children():
		_list.remove_child(old)
		old.queue_free()
	_add_line(tr("JOURNAL_TITLE"))
	var active := GameState.quests.active_ids()
	if active.is_empty():
		_add_line(tr("JOURNAL_EMPTY"))
	for quest_id: String in active:
		var quest := DataRegistry.entry("quests", quest_id)
		var step := GameState.quests.current_step(quest_id)
		_add_line("— %s" % tr(quest.get("name", quest_id)))
		_add_line(tr(quest.get("summary", "")), true)
		_add_line("▸ %s" % tr(step.get("text", "")))
	var palette := Palette.load_colors()
	for quest_id: String in DataRegistry.all("quests"):
		if GameState.quests.is_done(quest_id):
			var done := _add_line("✓ %s" % tr(DataRegistry.entry("quests", quest_id)["name"]))
			done.add_theme_color_override(&"font_color", palette[DONE_COLOR])


func _add_line(text: String, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = WIDTH - SPACING * 4
	_list.add_child(label)
	return label
