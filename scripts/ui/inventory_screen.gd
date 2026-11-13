class_name InventoryScreen
extends PanelContainer
## L'écran du sac : la grille des objets et la fiche de celui qui a le focus.
## Valider utilise l'objet ; quick_1 à quick_4 le placent dans un raccourci ; « crouch »
## le pose par terre (sauf un objet de quête).

const SLOT_SIZE := 36
const DETAILS_WIDTH := 150
const SPACING := 4
const QUEST_CATEGORY := "quete"

var _focused := 0
var _grid := GridContainer.new()
var _name := Label.new()
var _description := Label.new()
var _hint := Label.new()


func _init() -> void:
	hide()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", SPACING)
	add_child(rows)
	var title := Label.new()
	title.name = "Title"
	title.text = "INV_TITLE"
	rows.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", SPACING * 2)
	rows.add_child(columns)
	_grid.name = "Grid"
	_grid.add_theme_constant_override(&"h_separation", 1)
	_grid.add_theme_constant_override(&"v_separation", 1)
	columns.add_child(_grid)
	var details := VBoxContainer.new()
	details.custom_minimum_size.x = DETAILS_WIDTH
	columns.add_child(details)
	_name.name = "Name"
	details.add_child(_name)
	_description.name = "Description"
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(_description)
	_hint.name = "Hint"
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(_hint)


func _ready() -> void:
	EventBus.inventory_changed.connect(func(_item: String) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"crouch"):
		_drop_one()
	for index: int in Inventory.QUICK_SLOT_COUNT:
		if event.is_action_pressed(Player.QUICK_ACTION % (index + 1)):
			GameState.inventory.assign_quick_slot(index, _item_at(_focused))


func open() -> void:
	show()
	_hint.text = tr("INV_HINT_PAD" if InputHints.using_pad else "INV_HINT_KEYS")
	_refresh()
	_focus(0)


func close() -> void:
	hide()


# Remet la grille à l'image du sac : autant de cases, leurs icônes, leurs nombres.
func _refresh() -> void:
	if not visible:
		return
	var inventory := GameState.inventory
	_grid.columns = inventory.columns
	while _grid.get_child_count() > inventory.slots.size():
		var extra := _grid.get_child(_grid.get_child_count() - 1)
		_grid.remove_child(extra)
		extra.queue_free()
	while _grid.get_child_count() < inventory.slots.size():
		_grid.add_child(_make_slot(_grid.get_child_count()))
	for index: int in inventory.slots.size():
		var slot: Dictionary = inventory.slots[index]
		var button: Button = _grid.get_child(index)
		var count: Label = button.get_node("Count")
		var amount: int = slot.get("count", 0)
		button.icon = ItemIcon.of(slot.get("id", ""))
		count.text = str(amount) if amount > 1 else ""
	_focus(mini(_focused, inventory.slots.size() - 1))


func _make_slot(index: int) -> Button:
	var button := Button.new()
	button.name = "Slot%d" % index
	button.custom_minimum_size = Vector2.ONE * SLOT_SIZE
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_entered.connect(_on_slot_focused.bind(index))
	button.pressed.connect(_use.bind(index))
	var count := Label.new()
	count.name = "Count"
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count.position -= Vector2(2, 1)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(count)
	return button


func _focus(index: int) -> void:
	if index >= 0 and index < _grid.get_child_count():
		var button: Button = _grid.get_child(index)
		button.grab_focus()
		_on_slot_focused(index)


func _on_slot_focused(index: int) -> void:
	_focused = index
	var item := DataRegistry.entry("items", _item_at(index))
	_name.text = tr(item["name"]) if not item.is_empty() else ""
	_description.text = tr(item["description"]) if not item.is_empty() else ""


func _item_at(index: int) -> String:
	var slots := GameState.inventory.slots
	if index < 0 or index >= slots.size():
		return ""
	return slots[index].get("id", "")


func _use(index: int) -> void:
	var item_id := _item_at(index)
	if not item_id.is_empty() and not GameState.use_item(item_id):
		EventBus.notified.emit("INV_NO_USE")


func _drop_one() -> void:
	var item_id := _item_at(_focused)
	var item := DataRegistry.entry("items", item_id)
	if item.is_empty():
		return
	if item.get("category") == QUEST_CATEGORY:
		EventBus.notified.emit("INV_NO_DROP")
		return
	if GameState.inventory.remove(item_id, 1):
		EventBus.item_dropped.emit(item_id, 1)
