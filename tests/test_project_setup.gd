extends GutTest


func test_engine_matches_pinned_version() -> void:
	var pinned := FileAccess.get_file_as_string("res://.godot-version").strip_edges()
	var info := Engine.get_version_info()
	assert_eq("%d.%d.%d-%s" % [info.major, info.minor, info.patch, info.status], pinned)


func test_renderer_is_compatibility() -> void:
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility"
	)


func test_static_typing_is_enforced() -> void:
	assert_eq(ProjectSettings.get_setting("debug/gdscript/warnings/untyped_declaration"), 2)


func test_physics_is_interpolated() -> void:
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"))


func test_jitter_fix_is_off_with_physics_interpolation() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_jitter_fix"), 0.0)


func test_main_scene_is_set() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(main_scene, "res://scenes/main/game.tscn")


func test_the_game_starts_a_new_game_in_akans_room() -> void:
	GameState.new_game()
	var game: Main = load("res://scenes/main/game.tscn").instantiate()
	add_child_autofree(game)
	await wait_process_frames(3)
	assert_eq(GameState.place_id(), "appartement_akan")
	assert_true(GameState.quests.is_active(GameState.FIRST_QUEST))
	assert_true(GameState.playing)
	GameState.playing = false
	GameState.new_game()
