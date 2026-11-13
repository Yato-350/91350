extends GutTest

const SCENE := preload("res://scenes/main/main.tscn")


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	get_tree().paused = false


func test_the_inventory_action_opens_the_bag_and_pauses_the_game() -> void:
	var main := await _make_main()
	var screens: Screens = main.get_node("UI/Screens")
	assert_false(screens.is_open())
	_send_action("inventory")
	await wait_process_frames(2)
	assert_true(screens.is_open())
	assert_true(get_tree().paused)
	assert_true(screens.get_node("Inventory").visible)
	_send_action("inventory")
	await wait_process_frames(2)
	assert_false(screens.is_open())
	assert_false(get_tree().paused)


func test_cancel_closes_the_open_screen() -> void:
	var main := await _make_main()
	var screens: Screens = main.get_node("UI/Screens")
	screens.open("Inventory")
	_send_action("ui_cancel")
	await wait_process_frames(2)
	assert_false(screens.is_open())
	assert_false(get_tree().paused)


func test_only_one_screen_is_open_at_a_time() -> void:
	var main := await _make_main()
	var screens: Screens = main.get_node("UI/Screens")
	screens.open("Inventory")
	screens.open("Licorne")
	assert_true(screens.get_node("Inventory").visible, "écran inconnu : rien ne change")
	screens.close()
	assert_false(screens.get_node("Inventory").visible)


func _make_main() -> Main:
	var main: Main = SCENE.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


func _send_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


func test_the_journal_lists_quests_and_their_objectives() -> void:
	var main := await _make_main()
	GameState.quests.start(GameState.FIRST_QUEST)
	var screens: Screens = main.get_node("UI/Screens")
	_send_action("journal")
	await wait_process_frames(2)
	assert_true(screens.is_open())
	var journal: Control = screens.get_node("Journal")
	assert_true(journal.visible)
	var text := _all_text(journal)
	assert_string_contains(text, tr("QUEST_ASCENSEUR"))
	assert_string_contains(text, tr("OBJ_ASCENSEUR_PARLER"))
	_send_action("journal")
	await wait_process_frames(2)
	assert_false(screens.is_open())


func _all_text(node: Node) -> String:
	var text := ""
	for child: Node in node.find_children("*", "Label", true, false):
		text += (child as Label).text + "\n"
	return text
