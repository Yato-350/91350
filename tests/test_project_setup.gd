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


func test_main_scene_is_set() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_eq(main_scene, "res://scenes/main/main.tscn")
