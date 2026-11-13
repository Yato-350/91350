class_name CharacterVisual
extends Node3D
## Modèle voxel d'un personnage, animé par parties rigides (tête, torse, bras, jambes).
## Le modèle vient de tools/build_voxels.py, à partir de la fiche d'apparence du personnage.
##
## Deux rythmes : animate() suit le déplacement (orientation, foulée, course penchée,
## accroupi) ; update_pose() suit le temps (respiration, regard, geste en parlant, bras
## qui portent). _process() appelle update_pose() à chaque image.

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
const ARMS: Array[String] = ["ArmLeft", "ArmRight"]
const UPPER_BODY: Array[String] = ["Torso", "Head", "ArmLeft", "ArmRight"]
## Accroupi, le corps descend de cette hauteur et les jambes se plient d'autant.
const CROUCH_DROP := 0.3
const CROUCH_SPEED := 8.0
## Au repos, le haut du corps monte et descend d'un voxel : la respiration, en pixel art.
const BREATH_PERIOD := 2.4
const BREATH_STEP := 1.0 / 16.0
## En course, le corps se penche en avant et les membres battent plus large.
const RUN_START_SPEED := 3.0
const RUN_FULL_SPEED := 5.0
const RUN_LEAN := -0.17
const RUN_SWING_BONUS := 0.35
const LEAN_SPEED := 2.0
## La tête suit un point d'intérêt, sans se dévisser.
const HEAD_TURN_LIMIT := 1.1
const HEAD_TURN_SPEED := 6.0
## Porter une charge à deux mains, bras tendus devant soi.
const CARRY_ANGLE := -1.15
## En parlant : le bras droit accompagne la parole, la tête hoche.
const TALK_ARM := -0.45
const TALK_SWING := 0.25
const TALK_SPEED := 5.0
const NOD := 0.06
## Un coup de poing : le bras droit jaillit vers l'avant un instant.
const PUNCH_ANGLE := -1.6
const PUNCH_SECONDS := 0.2
## À terre : couché sur le ventre, un peu relevé pour ne pas traverser le sol.
const KNOCKED_OUT_TILT := -PI / 2.0
const KNOCKED_OUT_LIFT := 0.2

@export var character_id := "":
	set(value):
		character_id = value
		if is_node_ready():
			_load_model()

## Posture accroupie : le modèle s'y glisse en douceur.
var crouched := false
## Les bras portent une charge devant soi.
var carrying := false
## Le personnage parle : il accompagne ses phrases de gestes.
var talking := false
## Hors d'état : couché au sol, immobile.
var knocked_out := false:
	set(value):
		knocked_out = value
		rotation.x = KNOCKED_OUT_TILT if value else 0.0
		position.y = KNOCKED_OUT_LIFT if value else 0.0

var _model: Node3D
var _parts := {}
## Hauteur de repos de chaque partie, pour revenir debout.
var _rest_heights := {}
var _stride := 0.0
var _crouch := 0.0
var _speed := 0.0
var _swing := 0.0
var _time := 0.0
var _look_target := Vector3.INF
var _punch_time := 0.0


func _ready() -> void:
	_load_model()
	# Chacun respire à son rythme : pas de foule qui inspire d'un seul coup.
	_time = randf() * BREATH_PERIOD


func _process(delta: float) -> void:
	update_pose(delta)


func has_model() -> bool:
	return _model != null


func get_part(part_name: String) -> Node3D:
	return _parts.get(part_name)


## Tourne le modèle vers sa marche et balance bras et jambes selon la distance parcourue.
func animate(horizontal_velocity: Vector3, delta: float) -> void:
	_speed = Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z).length()
	if _speed > MOVING_SPEED:
		var facing := atan2(-horizontal_velocity.x, -horizontal_velocity.z)
		rotation.y = lerp_angle(rotation.y, facing, minf(1.0, TURN_SPEED * delta))
		_stride += _speed * delta * STRIDES_PER_METER * TAU
	else:
		_stride = 0.0
	var running := clampf((_speed - RUN_START_SPEED) / (RUN_FULL_SPEED - RUN_START_SPEED), 0.0, 1.0)
	var amplitude := minf(1.0, _speed / FULL_SWING_SPEED) + RUN_SWING_BONUS * running
	_swing = sin(_stride) * SWING_RADIANS * amplitude
	for part_name: String in LEGS:
		var leg: Node3D = _parts.get(part_name)
		if leg != null:
			leg.rotation.x = _swing if part_name in SWING_FORWARD else -_swing
	if not knocked_out:
		rotation.x = move_toward(rotation.x, RUN_LEAN * running, LEAN_SPEED * delta)
	_crouch = move_toward(_crouch, 1.0 if crouched else 0.0, CROUCH_SPEED * delta)
	_apply_pose()


## Un coup de poing (le bras droit, un instant).
func punch() -> void:
	_punch_time = PUNCH_SECONDS
	_apply_pose()


## Avance l'animation qui ne dépend que du temps : respiration, regard, gestes.
func update_pose(delta: float) -> void:
	_time += delta
	_punch_time = maxf(_punch_time - delta, 0.0)
	if knocked_out:
		return
	var head: Node3D = _parts.get("Head")
	if head != null:
		var wanted := 0.0
		if _look_target.is_finite():
			var local := global_basis.inverse() * (_look_target - global_position)
			wanted = clampf(atan2(-local.x, -local.z), -HEAD_TURN_LIMIT, HEAD_TURN_LIMIT)
		head.rotation.y = move_toward(head.rotation.y, wanted, HEAD_TURN_SPEED * delta)
		head.rotation.x = sin(_time * TALK_SPEED * 0.5) * NOD if talking else 0.0
	_apply_pose()


## La tête suit ce point (en coordonnées du monde) jusqu'à stop_looking().
func look_at_point(point: Vector3) -> void:
	_look_target = point


func stop_looking() -> void:
	_look_target = Vector3.INF


## Hauteur dont le corps est descendu, en mètres (0 debout).
func get_crouch_drop() -> float:
	return _crouch * CROUCH_DROP


# Hauteurs (accroupi, respiration) et bras (balancement, charge, geste).
func _apply_pose() -> void:
	var drop := get_crouch_drop()
	# Accroupi ou chargé, on retient son souffle : seul un corps au repos respire.
	var idle := _speed <= MOVING_SPEED and _crouch == 0.0 and not carrying
	var breath := BREATH_STEP if idle and fmod(_time, BREATH_PERIOD) > BREATH_PERIOD / 2.0 else 0.0
	for part_name: String in _parts:
		var part: Node3D = _parts[part_name]
		var rest: float = _rest_heights[part_name]
		part.position.y = rest - drop + (breath if part_name in UPPER_BODY else 0.0)
		# Les jambes, attachées à la hanche, raccourcissent pour que les pieds restent au sol.
		if part_name in LEGS and rest > 0.0:
			part.scale.y = (rest - drop) / rest
	for part_name: String in ARMS:
		var arm: Node3D = _parts.get(part_name)
		if arm == null:
			continue
		if _punch_time > 0.0 and part_name == "ArmRight":
			arm.rotation.x = PUNCH_ANGLE
		elif carrying:
			arm.rotation.x = CARRY_ANGLE
		elif talking and part_name == "ArmRight":
			arm.rotation.x = TALK_ARM + sin(_time * TALK_SPEED) * TALK_SWING
		else:
			arm.rotation.x = _swing if part_name in SWING_FORWARD else -_swing


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
