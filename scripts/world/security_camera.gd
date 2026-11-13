class_name SecurityCamera
extends Node3D
## Une caméra du régime : un mât, une tête qui balaie, un regard. Si elle voit Akan faire
## quelque chose d'interdit assez longtemps, elle le signale (Vigilance +1) et les Vigiles
## du coin accourent. Aveuglée (peinture, sabotage), elle ne voit plus rien.

const MODEL := "props/camera"
const EYE_HEIGHT := 2.6
const RANGE := 12.0
const HALF_ANGLE_DEGREES := 25.0
const SWEEP_PERIOD := 6.0
const PERCEPTION_SECONDS := 0.2
## Après un signalement, la caméra laisse aux Vigiles le temps d'arriver.
const REPORT_COOLDOWN := 6.0
const OFF_FLAG := "camera_off:%s"
const MAP_FLAG := "carte_surveillance"
const CONE_SEGMENTS := 12
const CONE_HEIGHT := 0.08
const CONE_MATERIAL := preload("res://shaders/vision_cone.gdshader")
const INDICATOR_HEIGHT := 3.3
const INDICATOR_SUSPICIOUS := "?"
const INDICATOR_SPOTTED := "!"
const FONT := preload("res://assets/fonts/Tiny5-Regular.ttf")
const DROOP := 0.6

var id := ""
## Amplitude du balayage, de part et d'autre de l'axe (radians).
var sweep := 0.0
var sight_range := RANGE
var nav: ZoneNavData
var awareness := Awareness.new()
var disabled := false

var _time := 0.0
var _since_perception := 0.0
var _cooldown := 0.0
var _head: Node3D
var _cone: MeshInstance3D
var _indicator: Label3D


## Crée la caméra décrite par une entrée « cameras » d'un lieu :
## {"id", "at", "yaw" (degrés), "sweep" (degrés), "range"}.
static func create(definition: Dictionary) -> SecurityCamera:
	var camera := SecurityCamera.new()
	camera.id = definition.get("id", "")
	camera.name = "Camera%s" % camera.id.to_pascal_case()
	camera.rotation.y = deg_to_rad(definition.get("yaw", 0.0))
	camera.sweep = deg_to_rad(definition.get("sweep", 0.0))
	camera.sight_range = definition.get("range", RANGE)
	return camera


func _ready() -> void:
	var model := VoxelModel.instantiate(MODEL)
	if model != null:
		add_child(model)
		_head = model.find_child("Head", true, false) as Node3D
	_cone = _make_cone()
	add_child(_cone)
	_indicator = Label3D.new()
	_indicator.font = FONT
	_indicator.font_size = 8
	_indicator.pixel_size = 1.0 / 16.0
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.no_depth_test = true
	_indicator.outline_size = 2
	_indicator.position.y = INDICATOR_HEIGHT
	add_child(_indicator)
	if GameState.has_flag(OFF_FLAG % id):
		disable()
	EventBus.flag_changed.connect(_on_flag_changed)
	_show_state()


func _process(delta: float) -> void:
	tick(delta)


## Avance la caméra de `delta` secondes : balayage, regard, signalement.
func tick(delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if disabled:
		return
	if _head != null:
		_head.rotation.y = head_yaw()
	_since_perception += delta
	if _since_perception < PERCEPTION_SECONDS:
		return
	_perceive(_since_perception)
	_since_perception = 0.0
	_show_state()


## L'angle de la tête par rapport à l'axe de la caméra.
func head_yaw() -> float:
	if sweep == 0.0:
		return 0.0
	return sin(_time * TAU / SWEEP_PERIOD) * sweep


## Aveugle la caméra pour de bon (le drapeau s'en souvient).
func disable() -> void:
	disabled = true
	awareness.value = 0.0
	GameState.set_flag(OFF_FLAG % id)
	if _head != null:
		_head.rotation.x = -DROOP
	_show_state()


# Un sabotage (dans un dialogue) pose le drapeau : l'image tombe aussitôt.
func _on_flag_changed(flag: String) -> void:
	if flag == OFF_FLAG % id and GameState.has_flag(flag) and not disabled:
		disable()


func _perceive(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		return
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var target := player.global_position
	var facing := global_rotation.y + head_yaw()
	var half := deg_to_rad(HALF_ANGLE_DEGREES)
	var seen := Vision.can_see(eye, facing, half, sight_range, target, nav)
	var distance := Vector2(target.x - eye.x, target.z - eye.z).length()
	awareness.update(
		delta, seen and GameState.is_offending(), distance, sight_range, player.crouched
	)
	if awareness.is_alerted() and _cooldown <= 0.0:
		awareness.value = 0.0
		_cooldown = REPORT_COOLDOWN
		GameState.surveillance.report(GameState.territory_id, 1.0)
		EventBus.player_spotted.emit(target, id)


func _show_state() -> void:
	if _indicator == null:
		return
	var palette := Palette.load_colors()
	_indicator.visible = not disabled and (awareness.is_suspicious() or _cooldown > 0.0)
	_indicator.text = INDICATOR_SPOTTED if _cooldown > 0.0 else INDICATOR_SUSPICIOUS
	_indicator.modulate = palette["rouge_propagande" if _cooldown > 0.0 else "jaune_linge"]
	_cone.visible = not disabled and GameState.has_flag(MAP_FLAG)
	_cone.rotation.y = head_yaw()


# Le cône au sol, en éventail : visible seulement avec la carte de surveillance.
func _make_cone() -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(HALF_ANGLE_DEGREES)
	for index: int in CONE_SEGMENTS:
		var a := -half + 2.0 * half * index / CONE_SEGMENTS
		var b := -half + 2.0 * half * (index + 1) / CONE_SEGMENTS
		for point: Vector3 in [
			Vector3.ZERO,
			Vector3(-sin(a), 0.0, -cos(a)) * sight_range,
			Vector3(-sin(b), 0.0, -cos(b)) * sight_range,
		]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point + Vector3.UP * CONE_HEIGHT)
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = CONE_MATERIAL
	cone.material_override = material
	return cone
