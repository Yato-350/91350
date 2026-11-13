extends GutTest
## Les menus : l'écran titre, la pause, la confirmation, la fin de l'acte 1. Chaque écran
## donne le focus à un bouton dès qu'il s'ouvre (clavier et manette).

const SCENE := preload("res://scenes/main/main.tscn")
const TEST_DIR := "user://test_menus"

var _original_dir: String


func before_each() -> void:
	GameState.new_game()
	_original_dir = SaveManager.save_dir
	SaveManager.save_dir = TEST_DIR
	_clear_test_dir()


func after_each() -> void:
	get_tree().paused = false
	_clear_test_dir()
	SaveManager.save_dir = _original_dir
	GameState.new_game()


func test_the_title_opens_over_a_sleeping_grigny() -> void:
	var main := await _make_main(true)
	var screens: Screens = main.get_node("UI/Screens")
	assert_eq(screens.top_name(), "Title")
	assert_true(get_tree().paused)
	assert_false(GameState.playing, "le temps ne passe pas au titre")
	assert_false(main.get_node("UI/Hud").visible)
	assert_true(_focus_is_on_a_button(), "un bouton a le focus")
	assert_true(_button(screens, "continue").disabled, "rien à continuer")
	var text := _texts(screens.get_node("Title"))
	assert_string_contains(text, "OpenStreetMap")


func test_a_new_game_starts_at_home() -> void:
	var main := await _make_main(true)
	var screens: Screens = main.get_node("UI/Screens")
	_button(screens, "new_game").pressed.emit()
	await wait_seconds(Main.TRAVEL_FADE_SECONDS * 2.0 + 0.2)
	assert_false(screens.is_open())
	assert_false(get_tree().paused)
	assert_true(GameState.playing)
	assert_eq(GameState.place_id(), "appartement_akan")
	assert_true(GameState.quests.is_active(GameState.FIRST_QUEST))
	assert_true(main.get_node("UI/Hud").visible)


func test_continue_reloads_the_last_save() -> void:
	GameState.enter("zone:palier_7", "grigny2")
	GameState.location = "zone:palier_7"
	assert_true(SaveManager.save_game())
	GameState.new_game()
	var main := await _make_main(true)
	var screens: Screens = main.get_node("UI/Screens")
	var resume := _button(screens, "continue")
	assert_false(resume.disabled)
	resume.pressed.emit()
	await wait_process_frames(3)
	assert_false(screens.is_open())
	assert_eq(GameState.place_id(), "palier_7")


func test_pause_opens_and_closes_with_its_key() -> void:
	var main := await _make_main(false)
	var screens: Screens = main.get_node("UI/Screens")
	_send_action("pause")
	await wait_process_frames(2)
	assert_eq(screens.top_name(), "Pause")
	assert_true(get_tree().paused)
	assert_true(_focus_is_on_a_button())
	_send_action("ui_cancel")
	await wait_process_frames(2)
	assert_false(screens.is_open())
	assert_false(get_tree().paused)


func test_saving_from_the_pause_menu() -> void:
	var main := await _make_main(false)
	var screens: Screens = main.get_node("UI/Screens")
	screens.open("Pause")
	_button(screens, "save").pressed.emit()
	await wait_process_frames(2)
	assert_true(SaveManager.has_save())
	assert_false(screens.is_open(), "on reprend après avoir sauvegardé")


func test_going_back_to_the_title_asks_first() -> void:
	var main := await _make_main(false)
	var screens: Screens = main.get_node("UI/Screens")
	screens.open("Pause")
	_button(screens, "title").pressed.emit()
	await wait_process_frames(2)
	assert_eq(screens.top_name(), "Confirm")
	assert_true(_focus_is_on_a_button(), "la confirmation prend le focus")
	_send_action("ui_cancel")
	await wait_process_frames(2)
	assert_eq(screens.top_name(), "Pause", "« non » rend la main au menu pause")
	assert_true(_focus_is_on_a_button(), "et son focus")
	_button(screens, "title").pressed.emit()
	await wait_process_frames(2)
	_button(screens, "yes").pressed.emit()
	await wait_process_frames(3)
	assert_eq(screens.top_name(), "Title")
	assert_false(GameState.playing)


func test_the_end_of_act_one_shows_what_akan_chose() -> void:
	var main := await _make_main(false)
	var screens: Screens = main.get_node("UI/Screens")
	GameState.set_flag("tag_humour")
	GameState.set_flag("bernard_double")
	GameState.set_flag("contact_rendu")
	EventBus.quest_completed.emit(Main.LAST_QUEST)
	await wait_process_frames(3)
	assert_eq(screens.top_name(), "ActEnd")
	assert_true(_focus_is_on_a_button())
	var text := _texts(screens.get_node("ActEnd"))
	assert_string_contains(text, tr("ACT1_TAG_HUMOUR"))
	assert_string_contains(text, tr("ACT1_BERNARD_DOUBLE"))
	assert_string_contains(text, tr("ACT1_CONTACT_RENDU"))
	_button(screens, "explore").pressed.emit()
	await wait_process_frames(2)
	assert_false(screens.is_open(), "on continue d'explorer Grigny libre")


func test_the_credits_open_from_the_title_and_close_with_cancel() -> void:
	var main := await _make_main(true)
	var screens: Screens = main.get_node("UI/Screens")
	_button(screens, "credits").pressed.emit()
	await wait_process_frames(2)
	assert_eq(screens.top_name(), "Credits")
	assert_string_contains(_texts(screens.get_node("Credits")), "ODbL")
	_send_action("ui_cancel")
	await wait_process_frames(2)
	assert_eq(screens.top_name(), "Title")
	assert_true(_focus_is_on_a_button())


func test_the_hideout_saves_the_game_on_arrival() -> void:
	var main := await _make_main(false)
	GameState.playing = true
	assert_false(SaveManager.has_save())
	main.travel_to("zone:local_tour")
	await wait_process_frames(2)
	assert_false(SaveManager.has_save(), "pas encore une planque")
	GameState.territory.liberate("grigny2")
	main.travel_to("zone:local_tour")
	await wait_process_frames(2)
	assert_true(SaveManager.has_save(), "la planque sauvegarde")


func _make_main(title: bool) -> Main:
	var main: Main = SCENE.instantiate()
	main.show_title = title
	main.start_place = Main.HOME
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


func _button(screens: Screens, id: String) -> Button:
	var button := screens.find_child(id, true, false) as Button
	assert_not_null(button, id)
	return button


func _focus_is_on_a_button() -> bool:
	return get_viewport().gui_get_focus_owner() is Button


func _texts(root: Node) -> String:
	var parts := PackedStringArray()
	for node: Node in root.find_children("*", "", true, false):
		if node is Label:
			parts.append((node as Label).text)
		elif node is RichTextLabel:
			parts.append((node as RichTextLabel).get_parsed_text())
	return "\n".join(parts)


func _send_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func _clear_test_dir() -> void:
	var dir := DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
