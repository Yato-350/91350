extends GutTest

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")


func before_each() -> void:
	GameState.new_game()


func test_player_focuses_the_nearest_interactable_in_range() -> void:
	var player := _make_player()
	_make_interactable(Vector3(5.0, 0.0, 0.0), "PROMPT_LOIN")
	var near := _make_interactable(Vector3(1.0, 0.0, 0.0), "PROMPT_PRES")
	var nearer := _make_interactable(Vector3(0.5, 0.0, 0.2), "PROMPT_TRES_PRES")
	watch_signals(EventBus)
	await wait_physics_frames(2)
	assert_eq(player.focus, nearer)
	assert_signal_emitted_with_parameters(
		EventBus, "interaction_focus_changed", ["PROMPT_TRES_PRES"]
	)
	nearer.enabled = false
	await wait_physics_frames(2)
	assert_eq(player.focus, near)
	near.position = Vector3(9.0, 0.0, 0.0)
	await wait_physics_frames(2)
	assert_null(player.focus)
	assert_signal_emitted_with_parameters(EventBus, "interaction_focus_changed", [""])


func test_interact_action_triggers_the_focused_interactable() -> void:
	var player := _make_player()
	var door := _make_interactable(Vector3(1.0, 0.0, 0.0), "PROMPT_ENTRER")
	watch_signals(door)
	await wait_physics_frames(2)
	_send_action("interact")
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(door, "interacted", [player])


func test_interact_action_does_nothing_out_of_range() -> void:
	_make_player()
	var door := _make_interactable(Vector3(4.0, 0.0, 0.0), "PROMPT_ENTRER")
	watch_signals(door)
	await wait_physics_frames(2)
	_send_action("interact")
	await wait_process_frames(2)
	assert_signal_not_emitted(door, "interacted")


func test_a_disabled_interactable_ignores_interact() -> void:
	var player := _make_player()
	var door := _make_interactable(Vector3(1.0, 0.0, 0.0), "PROMPT_ENTRER")
	door.enabled = false
	watch_signals(door)
	door.interact(player)
	assert_signal_not_emitted(door, "interacted")


func _make_player() -> Player:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = Vector3(0.0, 0.05, 0.0)
	add_child_autofree(player)
	return player


func _make_interactable(at: Vector3, prompt: String) -> Interactable:
	var interactable := Interactable.new()
	interactable.prompt = prompt
	interactable.position = at
	add_child_autofree(interactable)
	return interactable


func _send_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
