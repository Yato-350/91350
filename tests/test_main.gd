extends GutTest

const SCENE := preload("res://scenes/main/main.tscn")
const TEST_DIR := "user://test_saves"
const PARSE_CASES: Array = [
	[["--screenshot", "res://scenes/zones/test_zone.tscn"], "res://scenes/zones/test_zone.tscn"],
	[["--screenshot", "scenes/zones/test_zone.tscn"], "res://scenes/zones/test_zone.tscn"],
	[["--autre", "x", "--screenshot", "res://b.tscn"], "res://b.tscn"],
	[["--screenshot", "zone:grigny2"], "zone:grigny2"],
	[[], ""],
	[["--screenshot"], ""],
	[["--screenshot", "--autre"], ""],
	[["--autre"], ""],
]

var _original_dir: String


func before_each() -> void:
	GameState.new_game()
	_original_dir = SaveManager.save_dir
	SaveManager.save_dir = TEST_DIR
	_clear_test_dir()


func after_each() -> void:
	_clear_test_dir()
	SaveManager.save_dir = _original_dir


func test_parse_screenshot_scene(params: Array = use_parameters(PARSE_CASES)) -> void:
	var args := PackedStringArray(params[0])
	assert_eq(Main.parse_screenshot_scene(args), params[1])


func test_parse_hour() -> void:
	assert_eq(Main.parse_hour(PackedStringArray(["--hour", "23.5"])), 23.5)
	assert_eq(Main.parse_hour(PackedStringArray(["--hour"])), -1.0)
	assert_eq(Main.parse_hour(PackedStringArray(["--hour", "minuit"])), -1.0)
	assert_eq(Main.parse_hour(PackedStringArray([])), -1.0)


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
	await wait_process_frames(3)
	var reloaded := _player_of(main)
	assert_ne(reloaded, player, "le lieu est rechargé depuis la sauvegarde")
	# Le nouveau joueur a déjà commencé à se poser sur le sol.
	assert_almost_eq(reloaded.global_position, start, Vector3(0.001, 0.05, 0.001))


func test_travel_records_where_akan_is() -> void:
	var main := await _make_main()
	assert_eq(GameState.location, Main.DEFAULT_ZONE)
	assert_true(main.travel_to("zone:grigny2@gare"))
	await wait_process_frames(2)
	assert_eq(GameState.location, "zone:grigny2@gare")
	assert_eq(GameState.territory_id, "grigny2")
	assert_false(main.travel_to("zone:atlantide"))
	assert_push_error("atlantide")
	assert_eq(GameState.location, "zone:grigny2@gare")


func test_a_door_fades_out_travels_and_fades_back_in() -> void:
	var main := await _make_main()
	var fade: ColorRect = main.get_node("Overlay/Fade")
	EventBus.travel_requested.emit("appartement_akan@porte")
	EventBus.travel_requested.emit("hall_tour")
	await wait_seconds(Main.TRAVEL_FADE_SECONDS * 0.5)
	assert_gt(fade.color.a, 0.1)
	await wait_seconds(Main.TRAVEL_FADE_SECONDS * 2.0 + 0.1)
	assert_eq(GameState.location, "zone:appartement_akan@porte", "une seule porte à la fois")
	assert_eq(GameState.territory_id, "grigny2")
	assert_eq(fade.color.a, 0.0)


func test_the_view_comes_closer_indoors() -> void:
	var main := await _make_main()
	var view: PixelView = main.get_node("PixelView")
	main.travel_to("zone:hall_tour")
	assert_eq(view.zoom, Zone.INTERIOR_ZOOM)
	main.travel_to("zone:grigny2")
	assert_eq(view.zoom, 1)
	main.travel_to(Main.DEFAULT_ZONE)
	assert_eq(view.zoom, 1)


func test_a_knocked_out_akan_is_arrested_and_wakes_up_at_home() -> void:
	var main := await _make_main()
	main.travel_to("zone:grigny2")
	GameState.give("tickets", 10)
	GameState.clock.minutes = 22 * 60.0
	var day := GameState.clock.day
	GameState.vitals.damage(Vitals.MAX_HEALTH)
	await wait_seconds(Main.TRAVEL_FADE_SECONDS * 2.0 + 0.3)
	assert_eq(GameState.place_id(), "appartement_akan")
	assert_eq(GameState.clock.day, day + 1)
	assert_eq(GameState.clock.hour(), GameState.WAKE_HOUR)
	assert_eq(GameState.vitals.health, GameState.RELEASE_HEALTH)
	assert_eq(GameState.inventory.count("tickets"), 5, "la moitié confisquée")
	assert_eq(GameState.surveillance.status, Surveillance.Status.SURVEILLE)
	assert_true(GameState.has_flag("deja_arrete"))


func test_travel_can_place_akan_at_a_saved_position() -> void:
	var main := await _make_main()
	assert_true(main.travel_to(Main.DEFAULT_ZONE, [2.0, 0.5, -3.0]))
	await wait_process_frames(1)
	assert_almost_eq(_player_of(main).global_position, Vector3(2.0, 0.5, -3.0), Vector3.ONE * 0.01)


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
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


func _clear_test_dir() -> void:
	for file: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file))
