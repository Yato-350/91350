class_name Player
extends CharacterBody3D
## Akan : déplacement relatif à la caméra, course (endurance), accroupi, interactions.

const WALK_SPEED := 2.5
const RUN_SPEED := 5.5
const CROUCH_SPEED := 1.5
const ACCELERATION := 30.0
## Sous cette altitude, le joueur est tombé hors du monde : retour à l'apparition.
const FALL_LIMIT := -20.0
## Paramètre global des shaders : là où s'ouvre la vue à travers les bâtiments.
const SHADER_POSITION := &"player_position"
const GROUP := &"player"

## Accroupi : lent, silencieux, et jamais en course.
var crouched := false
## L'élément du monde avec lequel Akan peut interagir, ou null.
var focus: Interactable

var _spawn_position := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _visual: CharacterVisual = $Visual


## Direction de déplacement dans le monde pour une entrée du stick (x à droite,
## y vers le bas) vue depuis une caméra de lacet `camera_yaw`.
static func move_direction(input: Vector2, camera_yaw: float) -> Vector3:
	return Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, camera_yaw)


func _ready() -> void:
	add_to_group(GROUP)
	_spawn_position = global_position


func _process(_delta: float) -> void:
	var at := get_global_transform_interpolated().origin
	RenderingServer.global_shader_parameter_set(SHADER_POSITION, at)


func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT:
		teleport(_spawn_position)
		return
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var direction := move_direction(input, _camera_yaw())
	var wants_run := Input.is_action_pressed(&"run") and not direction.is_zero_approx()
	var running := wants_run and not crouched and GameState.vitals.can_run()
	GameState.tick_body(delta, running)
	var speed := CROUCH_SPEED if crouched else RUN_SPEED if running else WALK_SPEED
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(direction * speed, ACCELERATION * delta)
	velocity = Vector3(horizontal.x, velocity.y - _gravity * delta, horizontal.z)
	move_and_slide()
	_visual.crouched = crouched
	_visual.animate(horizontal, delta)
	_update_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"crouch"):
		crouched = not crouched
	elif event.is_action_pressed(&"interact") and focus != null:
		focus.interact(self)


func teleport(to: Vector3) -> void:
	global_position = to
	velocity = Vector3.ZERO
	# Sans cela, l'interpolation physique ferait glisser le joueur jusqu'à sa nouvelle place.
	reset_physics_interpolation()


# Vise l'élément interactif actif le plus proche, s'il est à portée.
func _update_focus() -> void:
	var nearest: Interactable = null
	var nearest_distance := INF
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var candidate := node as Interactable
		if candidate == null or not candidate.enabled:
			continue
		var distance := candidate.global_position.distance_to(global_position)
		if distance <= candidate.radius and distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	if nearest != focus:
		focus = nearest
		EventBus.interaction_focus_changed.emit(nearest.prompt if nearest != null else "")


func _camera_yaw() -> float:
	var camera := get_viewport().get_camera_3d()
	return camera.global_rotation.y if camera != null else 0.0
