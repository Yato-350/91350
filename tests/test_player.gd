extends GutTest

const SCENE := preload("res://scenes/actors/player.tscn")
const GAME_ACTIONS: Array[String] = [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"run",
	"camera_rotate_left",
	"camera_rotate_right",
	"crouch",
	"interact",
	"attack",
	"aim",
	"inventory",
	"journal",
	"pause",
	"quick_1",
	"quick_2",
	"quick_3",
	"quick_4",
]
const MOVE_ACTIONS: Array[String] = ["move_left", "move_right", "move_up", "move_down"]
const TOLERANCE := Vector3.ONE * 0.001


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	for action: String in GAME_ACTIONS:
		Input.action_release(action)


func test_move_direction_follows_the_camera_yaw() -> void:
	var yaw := deg_to_rad(45.0)
	var away := Vector3(-0.7071, 0.0, -0.7071)
	assert_almost_eq(Player.move_direction(Vector2.UP, yaw), away, TOLERANCE)
	assert_almost_eq(
		Player.move_direction(Vector2.RIGHT, yaw), Vector3(0.7071, 0.0, -0.7071), TOLERANCE
	)
	assert_almost_eq(Player.move_direction(Vector2.UP, 0.0), Vector3(0.0, 0.0, -1.0), TOLERANCE)


func test_move_direction_keeps_the_stick_magnitude() -> void:
	assert_almost_eq(Player.move_direction(Vector2(0.5, 0.0), 1.3).length(), 0.5, 0.001)
	assert_eq(Player.move_direction(Vector2.ZERO, 1.3), Vector3.ZERO)


func test_walks_when_an_action_is_pressed() -> void:
	var player := _make_player_on_floor()
	Input.action_press("move_right")
	await wait_physics_frames(30)
	assert_gt(player.position.x, 0.5)
	Input.action_release("move_right")
	await wait_physics_frames(30)
	var stopped_at := player.position.x
	await wait_physics_frames(10)
	assert_almost_eq(player.position.x, stopped_at, 0.001)


func test_running_covers_more_ground_than_walking() -> void:
	var walker := _make_player_on_floor()
	Input.action_press("move_right")
	await wait_physics_frames(40)
	var walked := walker.position.x
	walker.position.x = 0.0
	Input.action_press("run")
	await wait_physics_frames(40)
	assert_gt(walker.position.x, walked * 1.5)


func test_stays_on_the_floor() -> void:
	var player := _make_player_on_floor()
	await wait_physics_frames(60)
	assert_almost_eq(player.position.y, 0.0, 0.05)


func test_falling_out_of_the_world_respawns() -> void:
	var player := _make_player_on_floor()
	await wait_physics_frames(2)
	player.global_position = Vector3(50.0, Player.FALL_LIMIT - 1.0, 50.0)
	await wait_physics_frames(3)
	assert_almost_eq(player.global_position, Vector3(0.0, 0.05, 0.0), Vector3.ONE * 0.2)


func test_teleport_moves_the_player_and_stops_it() -> void:
	var player := _make_player_on_floor()
	Input.action_press("move_right")
	await wait_physics_frames(20)
	Input.action_release("move_right")
	player.teleport(Vector3(3.0, 0.05, -2.0))
	assert_almost_eq(player.global_position, Vector3(3.0, 0.05, -2.0), TOLERANCE)
	assert_eq(player.velocity, Vector3.ZERO)


func test_the_player_is_found_by_its_group_and_is_not_saved_by_itself() -> void:
	var player := _make_player_on_floor()
	assert_eq(get_tree().get_first_node_in_group(Player.GROUP), player)
	assert_false(player.is_in_group(SaveManager.SAVEABLE_GROUP))


func test_running_drains_stamina_and_exhaustion_forces_a_walk() -> void:
	var runner := _make_player_on_floor()
	Input.action_press("run")
	await wait_physics_frames(20)
	assert_eq(GameState.vitals.stamina, Vitals.MAX_STAMINA, "courir sur place ne coûte rien")
	Input.action_press("move_right")
	await wait_physics_frames(30)
	assert_lt(GameState.vitals.stamina, Vitals.MAX_STAMINA)
	GameState.vitals.tick(60.0, true, false)
	runner.teleport(Vector3(0.0, 0.05, 0.0))
	await wait_physics_frames(40)
	assert_lt(runner.position.x, 2.0, "essoufflé : il marche")


func test_crouching_toggles_and_is_slow_and_never_runs() -> void:
	var player := _make_player_on_floor()
	_send_action("crouch")
	await wait_physics_frames(2)
	assert_true(player.crouched)
	Input.action_press("move_right")
	Input.action_press("run")
	await wait_physics_frames(40)
	assert_between(player.position.x, 0.5, 1.2)
	assert_eq(GameState.vitals.stamina, Vitals.MAX_STAMINA)
	_send_action("crouch")
	await wait_physics_frames(2)
	assert_false(player.crouched)


func test_a_quick_slot_action_uses_its_item() -> void:
	_make_player_on_floor()
	GameState.needs.thirst = 10.0
	GameState.give("bouteille_eau", 1)
	GameState.inventory.assign_quick_slot(2, "bouteille_eau")
	_send_action("quick_3")
	await wait_process_frames(2)
	assert_gt(GameState.needs.thirst, 10.0)
	assert_eq(GameState.inventory.count("bouteille_eau"), 0)
	_send_action("quick_1")
	await wait_process_frames(2)
	pass_test("un raccourci vide ne fait rien")


func test_move_actions_use_physical_keys() -> void:
	for action: String in GAME_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null:
				assert_ne(key.physical_keycode, KEY_NONE, action)
				assert_eq(key.keycode, KEY_NONE, action)


func test_move_actions_have_a_dead_zone() -> void:
	for action: String in MOVE_ACTIONS:
		assert_almost_eq(InputMap.action_get_deadzone(action), 0.2, 0.001)


func test_each_action_has_keyboard_and_gamepad() -> void:
	for action: String in GAME_ACTIONS:
		var has_key := false
		var has_pad := false
		for event: InputEvent in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		assert_true(has_key and has_pad, action)


func test_actions_accept_any_device() -> void:
	for action: String in GAME_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			assert_eq(event.device, -1, action)


func _make_player_on_floor() -> Player:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)
	var player: Player = SCENE.instantiate()
	player.position = Vector3(0.0, 0.05, 0.0)
	add_child_autofree(player)
	return player


func _send_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
