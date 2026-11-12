class_name CameraRig
extends Node3D
## Caméra isométrique : suit une cible et tourne autour d'elle par pas de 90°.
##
## Le rig est posé sur la cible ; la caméra orthographique est son enfant, penchée
## de 30° et reculée. À 30° de tangage et 45° de lacet, les arêtes au sol tombent
## sur des lignes de pixels 2:1 bien nettes.
##
## Le rig réécrit la position de la caméra à chaque image : PixelView la décale
## ensuite pour la caler sur la grille de pixels.

const PITCH_DEGREES := 30.0
const YAW_OFFSET_DEGREES := 45.0
const STEP_DEGREES := 90.0
const STEP_COUNT := 4
const DISTANCE := 60.0
const ROTATION_SECONDS := 0.25

@export var target: Node3D

## Orientation demandée, en quarts de tour (0 à 3).
var yaw_step := 0

# Lacet affiché et lacet visé, non repliés sur 360° pour tourner par le plus court.
var _yaw_degrees := YAW_OFFSET_DEGREES
var _goal_yaw_degrees := YAW_OFFSET_DEGREES
var _rotation_tween: Tween

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_place()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"camera_rotate_left"):
		rotate_step(-1)
	if Input.is_action_just_pressed(&"camera_rotate_right"):
		rotate_step(1)
	_place()


## Tourne d'un quart de tour : +1 ou -1.
func rotate_step(direction: int) -> void:
	yaw_step = posmod(yaw_step + direction, STEP_COUNT)
	_goal_yaw_degrees += direction * STEP_DEGREES
	if _rotation_tween != null:
		_rotation_tween.kill()
	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, ^"_yaw_degrees", _goal_yaw_degrees, ROTATION_SECONDS)


func get_target_yaw_degrees() -> float:
	return YAW_OFFSET_DEGREES + STEP_DEGREES * yaw_step


func _place() -> void:
	if target != null:
		global_position = target.get_global_transform_interpolated().origin
	rotation_degrees.y = _yaw_degrees
	_camera.rotation_degrees = Vector3(-PITCH_DEGREES, 0.0, 0.0)
	_camera.position = _camera.basis.z * DISTANCE
