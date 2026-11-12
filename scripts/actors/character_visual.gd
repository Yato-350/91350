class_name CharacterVisual
extends Node3D
## Modèle voxel d'un personnage, animé par parties rigides (tête, torse, bras, jambes).
## Le modèle vient de tools/build_voxels.py, à partir de la fiche d'apparence du personnage.

const MODEL_PATH := "res://assets/voxel/characters/%s.glb"
const MATERIAL := preload("res://assets/materials/vertex_color.tres")
const STRIDES_PER_METER := 1.6
const SWING_RADIANS := 0.7
const TURN_SPEED := 12.0
## Vitesse à laquelle le balancement des membres est complet.
const FULL_SWING_SPEED := 2.5
const MOVING_SPEED := 0.1
# Les membres qui se balancent ensemble : jambe gauche avec bras droit, et inversement.
const SWING_FORWARD: Array[String] = ["LegLeft", "ArmRight"]
const SWING_BACKWARD: Array[String] = ["LegRight", "ArmLeft"]

@export var character_id := "":
	set(value):
		character_id = value
		if is_node_ready():
			_load_model()

var _model: Node3D
var _parts := {}
var _stride := 0.0


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


func _swing(part_name: String, angle: float) -> void:
	var part: Node3D = _parts.get(part_name)
	if part != null:
		part.rotation.x = angle


func _load_model() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	_parts.clear()
	if character_id.is_empty():
		return
	var path := MODEL_PATH % character_id
	if not ResourceLoader.exists(path):
		push_error("Modèle de personnage introuvable : %s" % character_id)
		return
	var scene: PackedScene = load(path)
	_model = scene.instantiate()
	add_child(_model)
	for node: Node in _model.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		part.material_override = MATERIAL
		_parts[String(part.name)] = part
