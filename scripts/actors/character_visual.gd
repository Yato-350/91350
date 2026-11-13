class_name CharacterVisual
extends Node3D
## Modèle voxel d'un personnage, animé par parties rigides (tête, torse, bras, jambes).
## Le modèle vient de tools/build_voxels.py, à partir de la fiche d'apparence du personnage.

const MODEL_FOLDER := "characters/"
const STRIDES_PER_METER := 1.6
const SWING_RADIANS := 0.7
const TURN_SPEED := 12.0
## Vitesse à laquelle le balancement des membres est complet.
const FULL_SWING_SPEED := 2.5
const MOVING_SPEED := 0.1
# Les membres qui se balancent ensemble : jambe gauche avec bras droit, et inversement.
const SWING_FORWARD: Array[String] = ["LegLeft", "ArmRight"]
const SWING_BACKWARD: Array[String] = ["LegRight", "ArmLeft"]
const LEGS: Array[String] = ["LegLeft", "LegRight"]
## Accroupi, le corps descend de cette hauteur et les jambes se plient d'autant.
const CROUCH_DROP := 0.3
const CROUCH_SPEED := 8.0

@export var character_id := "":
	set(value):
		character_id = value
		if is_node_ready():
			_load_model()

## Posture accroupie : le modèle s'y glisse en douceur.
var crouched := false

var _model: Node3D
var _parts := {}
## Hauteur de repos de chaque partie, pour revenir debout.
var _rest_heights := {}
var _stride := 0.0
var _crouch := 0.0


func _ready() -> void:
	_load_model()


func has_model() -> bool:
	return _model != null


func get_part(part_name: String) -> Node3D:
	return _parts.get(part_name)


## Tourne le modèle vers sa marche et balance bras et jambes selon la distance parcourue.
func animate(horizontal_velocity: Vector3, delta: float) -> void:
	var speed := Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z).length()
	if speed > MOVING_SPEED:
		var facing := atan2(-horizontal_velocity.x, -horizontal_velocity.z)
		rotation.y = lerp_angle(rotation.y, facing, minf(1.0, TURN_SPEED * delta))
		_stride += speed * delta * STRIDES_PER_METER * TAU
	else:
		_stride = 0.0
	var swing := sin(_stride) * SWING_RADIANS * minf(1.0, speed / FULL_SWING_SPEED)
	for part_name: String in SWING_FORWARD:
		_swing(part_name, swing)
	for part_name: String in SWING_BACKWARD:
		_swing(part_name, -swing)
	_crouch = move_toward(_crouch, 1.0 if crouched else 0.0, CROUCH_SPEED * delta)
	_apply_crouch()


## Hauteur dont le corps est descendu, en mètres (0 debout).
func get_crouch_drop() -> float:
	return _crouch * CROUCH_DROP


# Descend tout le corps ; les jambes, attachées à la hanche, raccourcissent pour que
# les pieds restent au sol.
func _apply_crouch() -> void:
	var drop := get_crouch_drop()
	for part_name: String in _parts:
		var part: Node3D = _parts[part_name]
		var rest: float = _rest_heights[part_name]
		part.position.y = rest - drop
		if part_name in LEGS and rest > 0.0:
			part.scale.y = (rest - drop) / rest


func _swing(part_name: String, angle: float) -> void:
	var part: Node3D = _parts.get(part_name)
	if part != null:
		part.rotation.x = angle


func _load_model() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	_parts.clear()
	_rest_heights.clear()
	if character_id.is_empty():
		return
	_model = VoxelModel.instantiate(MODEL_FOLDER + character_id, VoxelModel.CHARACTER_MATERIAL)
	if _model == null:
		return
	add_child(_model)
	for part: MeshInstance3D in VoxelModel.parts(_model):
		_parts[String(part.name)] = part
		_rest_heights[String(part.name)] = part.position.y
