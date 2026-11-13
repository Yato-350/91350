extends GutTest
## Les caméras du régime balaient, et signalent Akan quand il agit hors la loi.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")

var _camera: SecurityCamera
var _player: Player


func before_each() -> void:
	GameState.new_game()
	GameState.enter("zone:grigny2", "grigny2")
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)
	_camera = SecurityCamera.create({"id": "essai", "at": "0,0", "yaw": 0.0, "sweep": 0.0})
	add_child_autofree(_camera)
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	GameState.new_game()


func test_the_head_sweeps_from_side_to_side() -> void:
	var sweeping := SecurityCamera.create({"id": "balai", "at": "0,0", "yaw": 0.0, "sweep": 40.0})
	add_child_autofree(sweeping)
	var angles := {}
	for i: int in 30:
		sweeping.tick(0.25)
		angles[snappedf(sweeping.head_yaw(), 0.05)] = true
	assert_gt(angles.size(), 5)
	for angle: float in angles:
		assert_lte(absf(angle), deg_to_rad(40.0) + 0.01)


func test_an_honest_citizen_walks_past_freely() -> void:
	_player.teleport(Vector3(0.0, 0.05, -4.0))
	for i: int in 20:
		_camera.tick(0.25)
	assert_eq(GameState.surveillance.level("grigny2"), 0)


func test_an_offence_in_view_is_reported_and_alerts_the_area() -> void:
	watch_signals(EventBus)
	_player.teleport(Vector3(0.0, 0.05, -4.0))
	GameState.commit_offence()
	for i: int in 20:
		_camera.tick(0.25)
	assert_eq(GameState.surveillance.level("grigny2"), 1)
	assert_signal_emitted(EventBus, "player_spotted")


func test_out_of_the_cone_nothing_is_seen() -> void:
	_player.teleport(Vector3(0.0, 0.05, 4.0))
	GameState.commit_offence()
	for i: int in 20:
		_camera.tick(0.25)
	assert_eq(GameState.surveillance.level("grigny2"), 0, "derrière la caméra")


func test_a_blinded_camera_sees_nothing() -> void:
	_player.teleport(Vector3(0.0, 0.05, -4.0))
	GameState.commit_offence()
	_camera.disable()
	for i: int in 20:
		_camera.tick(0.25)
	assert_eq(GameState.surveillance.level("grigny2"), 0)
	assert_true(GameState.has_flag("camera_off:essai"), "la caméra reste aveugle")


func test_places_install_their_cameras_with_the_zone_grid() -> void:
	var hall := Zone.create("hall_tour")
	add_child_autofree(hall)
	await wait_process_frames(2)
	var camera: SecurityCamera = hall.get_node("CameraHall")
	assert_not_null(camera)
	assert_eq(camera.nav, hall.geometry.nav_data)
