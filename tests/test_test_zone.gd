extends GutTest

const SCENE := preload("res://scenes/zones/test_zone.tscn")
const SLAB_HALF_SIZE := 24.0

var _zone: Node3D
var _player: Player


func before_each() -> void:
	_zone = SCENE.instantiate()
	add_child_autofree(_zone)
	_player = _zone.get_node("Player")


func after_each() -> void:
	Input.action_release("move_down")
	Input.action_release("run")


func test_zone_has_one_player_and_an_orthographic_camera() -> void:
	assert_eq(_zone.find_children("*", "CharacterBody3D").size(), 1)
	var cameras := _zone.find_children("*", "Camera3D")
	assert_eq(cameras.size(), 1)
	var camera: Camera3D = cameras[0]
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_true(camera.current)


func test_player_rests_on_the_ground() -> void:
	await wait_physics_frames(60)
	assert_almost_eq(_player.position.y, 0.0, 0.1)


func test_player_cannot_leave_the_slab() -> void:
	Input.action_press("run")
	Input.action_press("move_down")
	await wait_physics_frames(300)
	assert_gt(_player.position.z, 15.0, "le joueur doit avoir atteint le muret")
	assert_lt(absf(_player.position.x), SLAB_HALF_SIZE)
	assert_lt(absf(_player.position.z), SLAB_HALF_SIZE)
