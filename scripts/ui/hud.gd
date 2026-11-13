class_name Hud
extends Control
## L'interface en jeu : jauges du corps, heure, lieu, Vigilance et statut citoyen,
## invite d'interaction, messages courts, raccourcis du sac, crédits.
## Elle est dessinée en pixels basse résolution ; Main l'agrandit à l'échelle entière.
## Chaque information est écrite : la couleur n'est jamais le seul signal.

const MESSAGE_SECONDS := 2.0
const DEBUG_SECONDS := 0.5
const MARGIN := 6
const BAR_SIZE := Vector2(48, 5)
const BAR_NAME_WIDTH := 36
const BAR_BACK_COLOR := "beton_1"
## Jauge → [nom affiché, couleur de palette].
const BARS := {
	"Health": ["HUD_HEALTH", "vert_feuille"],
	"Stamina": ["HUD_STAMINA", "jaune_linge"],
	"Hunger": ["HUD_HUNGER", "orange_sodium"],
	"Thirst": ["HUD_THIRST", "eau_claire"],
}
const QUICK_SLOT_SIZE := 34
const ZONE_PREFIX := "zone:"

var _palette := Palette.load_colors()
var _fills := {}
var _prompt_key := ""
var _debug_age := DEBUG_SECONDS
var _message_tween: Tween

@onready var _debug: Label = $Debug
@onready var _message: Label = $Message
@onready var _credits: Control = $Credits
@onready var _credits_text: RichTextLabel = $Credits/Margin/Text
@onready var _prompt: Label = _add_prompt()
@onready var _info: VBoxContainer = _add_info()
@onready var _quick_slots: HBoxContainer = _add_quick_slots()


func _ready() -> void:
	_add_bars()
	_message.hide()
	_credits.hide()
	_credits_text.text = (
		"%s\n\n%s\n\n%s" % [tr("CREDITS_TITLE"), tr("CREDITS_BODY"), Engine.get_license_text()]
	)
	EventBus.game_saved.connect(func(_slot: int) -> void: show_message("HUD_SAVED"))
	EventBus.game_loaded.connect(func(_slot: int) -> void: show_message("HUD_LOADED"))
	EventBus.notified.connect(show_message)
	EventBus.interaction_focus_changed.connect(_on_focus_changed)
	EventBus.inventory_changed.connect(func(_item: String) -> void: _refresh_quick_slots())
	EventBus.game_state_reset.connect(_refresh_all)
	EventBus.location_changed.connect(_refresh_place)
	EventBus.zone_liberated.connect(func(_zone: String) -> void: _refresh_place())
	EventBus.vigilance_changed.connect(func(_zone: String, _level: int) -> void: _refresh_place())
	EventBus.status_changed.connect(func(_status: int) -> void: _refresh_place())
	_refresh_all()


func _process(delta: float) -> void:
	_set_bar("Health", GameState.vitals.health / Vitals.MAX_HEALTH)
	_set_bar("Stamina", GameState.vitals.stamina / Vitals.MAX_STAMINA)
	_set_bar("Hunger", GameState.needs.hunger / Needs.MAX)
	_set_bar("Thirst", GameState.needs.thirst / Needs.MAX)
	var clock: Label = _info.get_node("Clock")
	clock.text = tr("HUD_CLOCK").format(
		{"day": GameState.clock.day, "time": GameState.clock.format()}
	)
	_debug_age += delta
	if _debug_age >= DEBUG_SECONDS:
		_debug_age = 0.0
		var version: String = ProjectSettings.get_setting("application/config/version")
		var values := {"version": version, "fps": roundi(Engine.get_frames_per_second())}
		_debug.text = tr("HUD_STATUS").format(values)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_credits"):
		_credits.visible = not _credits.visible


## Affiche un court message traduit, puis le masque.
func show_message(key: String) -> void:
	_message.text = tr(key)
	_message.show()
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_callback(_message.hide).set_delay(MESSAGE_SECONDS)


func _set_bar(bar: String, ratio: float) -> void:
	var fill: ColorRect = _fills[bar]
	fill.size.x = BAR_SIZE.x * clampf(ratio, 0.0, 1.0)


func _on_focus_changed(prompt_key: String) -> void:
	_prompt_key = prompt_key
	_prompt.visible = not prompt_key.is_empty()
	_prompt.text = "%s %s" % [InputHints.label(&"interact"), tr(prompt_key)]


func _refresh_all() -> void:
	_refresh_place()
	_refresh_quick_slots()


# Nom du lieu, Vigilance et statut : relus quand l'un d'eux change.
func _refresh_place() -> void:
	var place: Label = _info.get_node("Place")
	var vigilance: Label = _info.get_node("Vigilance")
	var status: Label = _info.get_node("Status")
	place.text = _place_name()
	var zone := GameState.territory_id
	var known := not zone.is_empty()
	vigilance.visible = known
	status.visible = known
	var level := GameState.surveillance.level(zone)
	vigilance.text = tr("HUD_VIGILANCE").format({"level": level, "max": Surveillance.MAX_LEVEL})
	status.text = tr("STATUS_%d" % GameState.surveillance.status)


# Un intérieur porte son propre nom ; une zone, celui du régime tant qu'elle n'est pas libre.
func _place_name() -> String:
	var place_id := GameState.place_id()
	var interior := DataRegistry.entry("interiors", place_id)
	if not interior.is_empty():
		return tr(interior["name"])
	var zone := DataRegistry.entry("zones", place_id)
	if zone.is_empty():
		return ""
	var freed := GameState.territory.is_liberated(place_id)
	return tr(zone["name_real"] if freed else zone["name_regime"])


func _refresh_quick_slots() -> void:
	var inventory := GameState.inventory
	for index: int in Inventory.QUICK_SLOT_COUNT:
		var slot := _quick_slots.get_child(index)
		var icon: TextureRect = slot.get_node("Icon")
		var count: Label = slot.get_node("Count")
		var item_id := inventory.quick_slots[index]
		icon.texture = ItemIcon.of(item_id)
		count.text = str(inventory.count(item_id)) if not item_id.is_empty() else ""


func _add_bars() -> void:
	var bars := VBoxContainer.new()
	bars.name = "Bars"
	bars.position = Vector2(MARGIN, MARGIN)
	bars.add_theme_constant_override(&"separation", 1)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bars)
	for bar: String in BARS:
		var row := HBoxContainer.new()
		row.name = bar
		row.add_theme_constant_override(&"separation", 2)
		bars.add_child(row)
		var label := Label.new()
		label.name = "Name"
		label.text = tr(BARS[bar][0])
		label.custom_minimum_size.x = BAR_NAME_WIDTH
		row.add_child(label)
		var back := ColorRect.new()
		back.name = "Bar"
		back.color = _palette[BAR_BACK_COLOR]
		back.custom_minimum_size = BAR_SIZE
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(back)
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.color = _palette[BARS[bar][1]]
		fill.size = BAR_SIZE
		back.add_child(fill)
		_fills[bar] = fill


func _add_info() -> VBoxContainer:
	var info := VBoxContainer.new()
	info.name = "Info"
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.position += Vector2(-MARGIN, MARGIN)
	info.add_theme_constant_override(&"separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(info)
	for line: String in ["Place", "Clock", "Vigilance", "Status"]:
		var label := Label.new()
		label.name = line
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		info.add_child(label)
	return info


func _add_prompt() -> Label:
	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt.position.y -= 56
	prompt.hide()
	add_child(prompt)
	return prompt


func _add_quick_slots() -> HBoxContainer:
	var slots := HBoxContainer.new()
	slots.name = "QuickSlots"
	slots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	slots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slots.position += Vector2(MARGIN, -MARGIN)
	slots.add_theme_constant_override(&"separation", 2)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slots)
	for index: int in Inventory.QUICK_SLOT_COUNT:
		var slot := PanelContainer.new()
		slot.name = "Slot%d" % (index + 1)
		slot.custom_minimum_size = Vector2.ONE * QUICK_SLOT_SIZE
		slots.add_child(slot)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		slot.add_child(icon)
		var key := Label.new()
		key.name = "Key"
		key.text = str(index + 1)
		key.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		slot.add_child(key)
		var count := Label.new()
		count.name = "Count"
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.size_flags_vertical = Control.SIZE_SHRINK_END
		slot.add_child(count)
	return slots
