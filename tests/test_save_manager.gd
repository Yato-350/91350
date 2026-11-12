extends GutTest

const TEST_DIR := "user://test_saves"

var _original_dir: String


class FakeSaveable:
	extends Node

	var save_id: StringName = &"fake"
	var state: Dictionary = {}

	func _init(id: StringName = &"fake") -> void:
		save_id = id
		add_to_group(SaveManager.SAVEABLE_GROUP)

	func save_state() -> Dictionary:
		return state.duplicate(true)

	func load_state(new_state: Dictionary) -> void:
		state = new_state


func before_each() -> void:
	_original_dir = SaveManager.save_dir
	SaveManager.save_dir = TEST_DIR
	_clear_test_dir()


func after_each() -> void:
	_clear_test_dir()
	SaveManager.save_dir = _original_dir


func test_save_then_load_restores_state() -> void:
	var node := _add_saveable()
	node.state = {"water": 12.5, "name": "akan"}
	assert_true(SaveManager.save_game())
	node.state = {"water": 0.0, "name": "personne"}
	assert_true(SaveManager.load_game())
	assert_eq(node.state, {"water": 12.5, "name": "akan"})


func test_load_without_file_returns_false() -> void:
	assert_false(SaveManager.has_save())
	assert_false(SaveManager.load_game())


func test_corrupted_file_is_refused_and_state_is_kept() -> void:
	var node := _add_saveable()
	node.state = {"water": 7.0}
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var file := FileAccess.open(SaveManager.slot_path(0), FileAccess.WRITE)
	file.store_string('{"save_version": 1, "sys')
	file.close()
	assert_false(SaveManager.load_game())
	assert_eq(node.state, {"water": 7.0})


func test_node_missing_from_the_save_keeps_its_state() -> void:
	var saved := _add_saveable(&"saved")
	saved.state = {"water": 1.0}
	SaveManager.save_game()
	var newcomer := _add_saveable(&"newcomer")
	newcomer.state = {"water": 99.0}
	assert_true(SaveManager.load_game())
	assert_eq(newcomer.state, {"water": 99.0})


func test_signals_carry_the_slot() -> void:
	_add_saveable()
	watch_signals(EventBus)
	SaveManager.save_game(2)
	SaveManager.load_game(2)
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [2])
	assert_signal_emitted_with_parameters(EventBus, "game_loaded", [2])


func test_no_temporary_file_is_left() -> void:
	_add_saveable()
	SaveManager.save_game()
	assert_eq(Array(DirAccess.get_files_at(TEST_DIR)), ["slot_0.json"])


func test_duplicate_save_ids_are_refused() -> void:
	_add_saveable(&"twin")
	_add_saveable(&"twin")
	assert_false(SaveManager.save_game())
	assert_push_error("twin")
	assert_false(SaveManager.has_save())


func test_node_without_save_contract_is_refused() -> void:
	var stranger := Node.new()
	stranger.add_to_group(SaveManager.SAVEABLE_GROUP)
	add_child_autofree(stranger)
	assert_false(SaveManager.save_game())
	assert_push_error("save_id")
	assert_false(SaveManager.has_save())


func _add_saveable(id: StringName = &"fake") -> FakeSaveable:
	var node := FakeSaveable.new(id)
	add_child_autofree(node)
	return node


func _clear_test_dir() -> void:
	for file: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file))
