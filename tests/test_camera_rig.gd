extends GutTest

const SCENE := preload("res://scenes/actors/camera_rig.tscn")


func after_each() -> void:
	Input.action_release("camera_rotate_left")
	Input.action_release("camera_rotate_right")


func test_initial_view_is_isometric() -> void:
	var rig := _make_rig()
	var camera: Camera3D = rig.get_node("Camera3D")
	assert_eq(rig.get_target_yaw_degrees(), 45.0)
	assert_almost_eq(rig.rotation_degrees.y, 45.0, 0.01)
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_almost_eq(camera.rotation_degrees.x, -30.0, 0.01)


func test_rotate_step_wraps_both_ways() -> void:
	var rig := _make_rig()
	for i: int in 4:
		rig.rotate_step(1)
	assert_eq(rig.yaw_step, 0)
	rig.rotate_step(-1)
	assert_eq(rig.yaw_step, 3)
	assert_eq(rig.get_target_yaw_degrees(), 315.0)


func test_rotation_reaches_the_target_yaw() -> void:
	var rig := _make_rig()
	rig.rotate_step(1)
	await wait_seconds(CameraRig.ROTATION_SECONDS + 0.1)
	assert_almost_eq(wrapf(rig.rotation_degrees.y, 0.0, 360.0), 135.0, 0.5)


func test_rotate_actions_turn_the_camera() -> void:
	var rig := _make_rig()
	Input.action_press("camera_rotate_right")
	await wait_process_frames(2)
	Input.action_release("camera_rotate_right")
	assert_eq(rig.yaw_step, 1)
	Input.action_press("camera_rotate_left")
	await wait_process_frames(2)
	assert_eq(rig.yaw_step, 0)


func test_rig_follows_its_target() -> void:
	var target := Node3D.new()
	add_child_autofree(target)
	var rig := _make_rig(target)
	target.global_position = Vector3(4.0, 0.0, -3.0)
	target.reset_physics_interpolation()
	await wait_process_frames(2)
	assert_almost_eq(rig.global_position, Vector3(4.0, 0.0, -3.0), Vector3.ONE * 0.001)


func test_rig_resets_the_camera_every_frame() -> void:
	var rig := _make_rig()
	var camera: Camera3D = rig.get_node("Camera3D")
	camera.position += Vector3(0.3, 0.2, 0.0)
	await wait_process_frames(2)
	assert_almost_eq(camera.position, Vector3(0.0, 30.0, 51.96), Vector3.ONE * 0.01)


func test_rig_without_target_stays_put() -> void:
	var rig := _make_rig()
	rig.global_position = Vector3(1.0, 2.0, 3.0)
	await wait_process_frames(2)
	assert_eq(rig.global_position, Vector3(1.0, 2.0, 3.0))


func _make_rig(target: Node3D = null) -> CameraRig:
	var rig: CameraRig = SCENE.instantiate()
	rig.target = target
	add_child_autofree(rig)
	return rig
