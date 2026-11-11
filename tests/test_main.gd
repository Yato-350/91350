extends GutTest

const SCENE := preload("res://scenes/main/main.tscn")
const TEST_DIR := "user://test_saves"
const PARSE_CASES: Array = [
	[["--screenshot", "res://scenes/zones/test_zone.tscn"], "res://scenes/zones/test_zone.tscn"],
	[["--screenshot", "scenes/zones/test_zone.tscn"], "res://scenes/zones/test_zone.tscn"],
	[["--autre", "x", "--screenshot", "res://b.tscn"], "res://b.tscn"],
	[[], ""],
	[["--screenshot"], ""],
	[["--screenshot", "--autre"], ""],
	[["--autre"], ""],
]

var _original_dir: String


func before_each() -> void:
	_original_dir = SaveManager.save_dir
	SaveManager.save_dir = TEST_DIR
	_clear_test_dir()


func after_each() -> void:
	_clear_test_dir()
	SaveManager.save_dir = _original_dir


func test_parse_screenshot_scene(params: Array = use_parameters(PARSE_CASES)) -> void:
	var args := PackedStringArray(params[0])
	assert_eq(Main.parse_screenshot_scene(args), params[1])


func test_main_loads_the_default_zone() -> void:
	var main := await _make_main()
	var view: PixelView = main.get_node("PixelView")
	assert_not_null(view.get_zone())
	assert_eq(view.get_zone().scene_file_path, Main.DEFAULT_ZONE)


func test_load_zone_refuses_a_missing_scene() -> void:
	var main := await _make_main()
	var view: PixelView = main.get_node("PixelView")
	var zone := view.get_zone()
	assert_false(main.load_zone("res://absent.tscn"))
	assert_push_error("absent.tscn")
	assert_eq(view.get_zone(), zone)


func test_quick_save_then_quick_load_restores_the_player() -> void:
	var main := await _make_main()
	var player := _player_of(main)
	player.set_physics_process(false)
	var start := player.global_position
	_send_action("quick_save")
	await wait_process_frames(2)
	assert_true(SaveManager.has_save())
	player.global_position = start + Vector3(3.0, 0.0, 2.0)
	_send_action("quick_load")
	await wait_process_frames(2)
	assert_almost_eq(player.global_position, start, Vector3.ONE * 0.001)


func test_colour_toggle_requests_the_other_saturation() -> void:
	var main := await _make_main()
	var view: PixelView = main.get_node("PixelView")
	_send_action("debug_toggle_color")
	await wait_seconds(Main.COLOR_FADE_SECONDS + 0.2)
	assert_eq(view.saturation, 0.0)


func test_camera_snap_does_not_accumulate() -> void:
	var main := await _make_main()
	var player := _player_of(main)
	player.set_physics_process(false)
	var view: PixelView = main.get_node("PixelView")
	var camera := view.get_world_viewport().get_camera_3d()
	for i: int in 30:
		player.global_position += Vector3(0.013, 0.0, 0.007)
		player.reset_physics_interpolation()
		await wait_process_frames(1)
		var camera_basis := camera.global_basis
		var ideal := player.global_position + camera_basis.z * CameraRig.DISTANCE
		var expected := PixelSnap.snap_position(ideal, camera_basis, PixelSnap.TEXEL)
		assert_almost_eq(camera.global_position, expected, Vector3.ONE * 0.001)


func _make_main() -> Main:
	var main: Main = SCENE.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


func _player_of(main: Main) -> Player:
	var view: PixelView = main.get_node("PixelView")
	return view.get_zone().get_node("Player")


func _send_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _clear_test_dir() -> void:
	for file: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file))
