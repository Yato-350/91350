extends GutTest

var _screen: InventoryScreen


func before_each() -> void:
	GameState.new_game()
	_screen = InventoryScreen.new()
	add_child_autofree(_screen)


func after_each() -> void:
	get_tree().paused = false
	Input.action_release("crouch")


func test_opening_shows_one_slot_per_cell_of_the_bag() -> void:
	assert_false(_screen.visible)
	_screen.open()
	assert_true(_screen.visible)
	assert_eq(_slots().size(), 12)
	GameState.give("sac_petit", 1)
	GameState.use_item("sac_petit")
	assert_eq(_slots().size(), 20, "le sac a grandi : la grille aussi")
	_screen.close()
	assert_false(_screen.visible)


func test_a_slot_shows_its_item_and_the_details_follow_the_focus() -> void:
	GameState.give("bouteille_eau", 3)
	GameState.give("batte", 1)
	_screen.open()
	var first := _slots()[0]
	assert_not_null(first.icon)
	assert_eq(_count_of(first), "3")
	assert_eq(_count_of(_slots()[1]), "", "un seul objet : pas de chiffre")
	assert_eq(_text("Name"), tr("ITEM_BOUTEILLE_EAU"), "la première case a le focus")
	_slots()[1].grab_focus()
	assert_eq(_text("Name"), tr("ITEM_BATTE"))
	assert_eq(_text("Description"), tr("ITEM_BATTE_DESC"))
	_slots()[5].grab_focus()
	assert_eq(_text("Name"), "")


func test_pressing_a_slot_uses_its_item() -> void:
	GameState.needs.thirst = 10.0
	GameState.give("bouteille_eau", 2)
	_screen.open()
	_slots()[0].pressed.emit()
	assert_gt(GameState.needs.thirst, 10.0)
	assert_eq(_count_of(_slots()[0]), "", "il n'en reste qu'une")
	assert_eq(GameState.inventory.count("bouteille_eau"), 1)


func test_a_quick_action_assigns_the_focused_item_to_a_shortcut() -> void:
	GameState.give("bouteille_eau", 1)
	_screen.open()
	_send_action("quick_3")
	await wait_process_frames(2)
	assert_eq(GameState.inventory.quick_slots[2], "bouteille_eau")


func test_the_drop_action_puts_one_item_down_but_never_a_quest_item() -> void:
	GameState.give("bouteille_eau", 2)
	GameState.give("bidon_vide", 1)
	_screen.open()
	watch_signals(EventBus)
	_send_action("crouch")
	await wait_process_frames(2)
	assert_eq(GameState.inventory.count("bouteille_eau"), 1)
	assert_signal_emitted_with_parameters(EventBus, "item_dropped", ["bouteille_eau", 1])
	_slots()[1].grab_focus()
	_send_action("crouch")
	await wait_process_frames(2)
	assert_eq(GameState.inventory.count("bidon_vide"), 1, "un objet de quête ne se pose pas")


func _slots() -> Array[Button]:
	var buttons: Array[Button] = []
	for node: Node in _screen.find_child("Grid", true, false).get_children():
		buttons.append(node as Button)
	return buttons


func _count_of(slot: Button) -> String:
	var label: Label = slot.get_node("Count")
	return label.text


func _text(node_name: String) -> String:
	var label: Label = _screen.find_child(node_name, true, false)
	return label.text


func _send_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
