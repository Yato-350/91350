class_name Player
extends CharacterBody3D
## Akan : déplacement relatif à la caméra, au clavier comme à la manette.
## Le visuel en boîtes est provisoire (remplacé par le pipeline voxel au jalon M1).

const WALK_SPEED := 2.5
const RUN_SPEED := 5.5
const ACCELERATION := 30.0
const TURN_SPEED := 12.0
## Sous cette altitude, le joueur est tombé hors du monde : retour à l'apparition.
const FALL_LIMIT := -20.0
const STRIDES_PER_METER := 1.6
const SWING_RADIANS := 0.7

@export var save_id: StringName = &"player"

var _spawn_position := Vector3.ZERO
var _stride := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _visual: Node3D = $Visual
@onready var _swinging: Array[Node3D] = [
	$Visual/LegLeft, $Visual/ArmRight, $Visual/LegRight, $Visual/ArmLeft
]


## Direction de déplacement dans le monde pour une entrée du stick (x à droite,
## y vers le bas) vue depuis une caméra de lacet `camera_yaw`.
static func move_direction(input: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw)


func _ready() -> void:
	_spawn_position = global_position


func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT:
		_teleport(_spawn_position)
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var direction := move_direction(input, _camera_yaw())
	var speed := RUN_SPEED if Input.is_action_pressed(&"run") else WALK_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(direction * speed, ACCELERATION * delta)
	velocity = Vector3(horizontal.x, velocity.y - _gravity * delta, horizontal.z)
	move_and_slide()
	_animate(horizontal, delta)


func save_state() -> Dictionary:
	var at := global_position
	return {"position": [at.x, at.y, at.z], "yaw": _visual.rotation.y}


## Ignore un état mal formé : la position actuelle est conservée.
func load_state(state: Dictionary) -> void:
	var raw: Variant = state.get("position")
	if not raw is Array or raw.size() != 3:
		return
	for value: Variant in raw:
		if not (value is float or value is int):
			return
	_teleport(Vector3(raw[0], raw[1], raw[2]))
	var yaw: Variant = state.get("yaw")
	if yaw is float or yaw is int:
		_visual.rotation.y = yaw


func _teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	# Sans cela, l'interpolation physique ferait glisser le joueur jusqu'à sa nouvelle place.
	reset_physics_interpolation()


func _camera_yaw() -> float:
	var camera := get_viewport().get_camera_3d()
	return camera.global_rotation.y if camera != null else 0.0


# Tourne le visuel vers la marche et balance bras et jambes selon la distance parcourue.
func _animate(horizontal: Vector3, delta: float) -> void:
	var speed := horizontal.length()
	if speed > 0.1:
		var facing := atan2(-horizontal.x, -horizontal.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, facing, minf(1.0, TURN_SPEED * delta))
		_stride += speed * delta * STRIDES_PER_METER * TAU
	else:
		_stride = 0.0
	var swing := sin(_stride) * SWING_RADIANS * minf(1.0, speed / WALK_SPEED)
	for index: int in _swinging.size():
		_swinging[index].rotation.x = swing if index < 2 else -swing
