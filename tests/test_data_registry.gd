extends GutTest

const TEMP_DIR := "user://test_data"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR.path_join("items"))


func after_each() -> void:
	for file_name: String in DirAccess.get_files_at(TEMP_DIR.path_join("items")):
		DirAccess.remove_absolute(TEMP_DIR.path_join("items").path_join(file_name))
	DataRegistry.clear_cache()


func test_reads_the_game_data_by_type_and_id() -> void:
	assert_eq(DataRegistry.entry("characters", "akan")["name"], "CHAR_AKAN")
	assert_gt(DataRegistry.all("characters").size(), 20)
	assert_eq(DataRegistry.entry("characters", "personne"), {})
	assert_eq(DataRegistry.all("licornes"), {})


func test_a_file_can_hold_one_entry_or_a_list() -> void:
	_write("items/list.json", '{"items": [{"id": "eau", "stack": 5}, {"id": "pain"}]}')
	_write("items/single.json", '{"id": "batte", "stack": 1}')
	_write("items/readme.txt", "pas du JSON")
	var items := DataRegistry.load_dir(TEMP_DIR.path_join("items"), "items")
	assert_eq(items.size(), 3)
	assert_eq(items["eau"]["stack"], 5.0)
	assert_eq(items["batte"]["id"], "batte")


func test_a_broken_file_is_reported_and_skipped() -> void:
	_write("items/ok.json", '{"items": [{"id": "eau"}]}')
	_write("items/broken.json", '{"items": [')
	_write("items/no_id.json", '{"items": [{"nom": "x"}]}')
	var items := DataRegistry.load_dir(TEMP_DIR.path_join("items"), "items")
	assert_eq(items.keys(), ["eau"])
	assert_push_error("broken.json")
	assert_push_error("no_id.json")


func _write(relative_path: String, text: String) -> void:
	var file := FileAccess.open(TEMP_DIR.path_join(relative_path), FileAccess.WRITE)
	file.store_string(text)
	file.close()
