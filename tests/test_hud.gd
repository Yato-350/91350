extends GutTest

const SCENE := preload("res://scenes/ui/hud.tscn")

var _hud: Hud


func before_each() -> void:
	GameState.new_game()
	InputHints.using_pad = false
	_hud = SCENE.instantiate()
	add_child_autofree(_hud)


func after_each() -> void:
	InputHints.using_pad = false


func test_bars_follow_the_body() -> void:
	GameState.vitals.damage(50.0)
	GameState.needs.thirst = 25.0
	await wait_process_frames(2)
	assert_almost_eq(_bar_ratio("Health"), 0.5, 0.02)
	assert_almost_eq(_bar_ratio("Thirst"), 0.25, 0.02)
	assert_almost_eq(_bar_ratio("Stamina"), 1.0, 0.02)
	assert_almost_eq(_bar_ratio("Hunger"), 1.0, 0.02)


func test_each_bar_is_named_not_only_coloured() -> void:
	for bar: String in ["Health", "Stamina", "Hunger", "Thirst"]:
		var label: Label = _hud.get_node("Bars/%s/Name" % bar)
		assert_false(label.text.is_empty(), bar)


func test_clock_and_day_are_shown() -> void:
	GameState.clock.minutes = 20 * 60.0 + 52.0
	GameState.clock.day = 3
	await wait_process_frames(2)
	assert_string_contains(_text("Info/Clock"), "20:52")
	assert_string_contains(_text("Info/Clock"), "3")


func test_place_name_is_the_regime_name_until_the_zone_is_free() -> void:
	GameState.enter("zone:grigny2@gare", "grigny2")
	assert_eq(_text("Info/Place"), tr("ZONE_GRIGNY2_REGIME"))
	GameState.territory.liberate("grigny2")
	assert_eq(_text("Info/Place"), tr("ZONE_GRIGNY2_REAL"))
	GameState.enter("zone:appartement_akan", "grigny2")
	assert_eq(_text("Info/Place"), tr("PLACE_APPARTEMENT_AKAN"))
	GameState.enter("res://scenes/zones/test_zone.tscn", "")
	assert_eq(_text("Info/Place"), "")


func test_vigilance_and_status_are_written() -> void:
	GameState.enter("zone:grigny2", "grigny2")
	assert_string_contains(_text("Info/Vigilance"), "0")
	assert_eq(_text("Info/Status"), tr("STATUS_0"))
	GameState.surveillance.report("grigny2", 3.0)
	assert_string_contains(_text("Info/Vigilance"), "3")
	assert_eq(_text("Info/Status"), tr("STATUS_1"))


func test_prompt_names_the_key_and_the_action() -> void:
	var prompt: Label = _hud.get_node("Prompt")
	assert_false(prompt.visible)
	EventBus.interaction_focus_changed.emit("PROMPT_ENTRER")
	assert_true(prompt.visible)
	assert_eq(prompt.text, "[F] %s" % tr("PROMPT_ENTRER"))
	InputHints.using_pad = true
	EventBus.interaction_focus_changed.emit("PROMPT_ENTRER")
	assert_eq(prompt.text, "(A) %s" % tr("PROMPT_ENTRER"))
	EventBus.interaction_focus_changed.emit("")
	assert_false(prompt.visible)


func test_a_dialogue_takes_the_bottom_of_the_screen() -> void:
	var prompt: Label = _hud.get_node("Prompt")
	var slots: Control = _hud.get_node("QuickSlots")
	EventBus.interaction_focus_changed.emit("PROMPT_PARLER")
	EventBus.dialogue_requested.emit("daronne", "")
	assert_false(prompt.visible)
	assert_false(slots.visible)
	EventBus.dialogue_ended.emit("daronne")
	assert_true(prompt.visible)
	assert_true(slots.visible)


func test_the_current_objective_is_written() -> void:
	var objective: Label = _hud.get_node("Objective")
	assert_eq(objective.text, "")
	GameState.quests.start(GameState.FIRST_QUEST)
	assert_eq(objective.text, tr("OBJ_ASCENSEUR_PARLER"))
	GameState.quests.notify("TALK", "daronne")
	assert_eq(objective.text, tr("OBJ_ASCENSEUR_BOIRE"))


func test_notifications_show_a_short_message() -> void:
	var message: Label = _hud.get_node("Message")
	assert_false(message.visible)
	EventBus.notified.emit("HUD_BAG_FULL")
	assert_true(message.visible)
	assert_eq(message.text, tr("HUD_BAG_FULL"))
	await wait_seconds(Hud.MESSAGE_SECONDS + 0.2)
	assert_false(message.visible)


func test_quick_slots_show_the_item_and_its_count() -> void:
	GameState.give("bouteille_eau", 3)
	GameState.inventory.assign_quick_slot(1, "bouteille_eau")
	var icon: TextureRect = _hud.get_node("QuickSlots/Slot2/Icon")
	var count: Label = _hud.get_node("QuickSlots/Slot2/Count")
	assert_not_null(icon.texture)
	assert_eq(count.text, "3")
	GameState.use_item("bouteille_eau")
	assert_eq(count.text, "2")
	var empty_icon: TextureRect = _hud.get_node("QuickSlots/Slot1/Icon")
	assert_null(empty_icon.texture)
	GameState.use_item("bouteille_eau")
	GameState.use_item("bouteille_eau")
	assert_null(icon.texture, "plus rien : le raccourci se vide")
	assert_eq(count.text, "")


func _bar_ratio(bar: String) -> float:
	var back: Control = _hud.get_node("Bars/%s/Bar" % bar)
	var fill: Control = back.get_node("Fill")
	return fill.size.x / back.size.x


func _text(path: String) -> String:
	var label: Label = _hud.get_node(path)
	return label.text
