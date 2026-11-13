class_name Vigile
extends CharacterBody3D
## Un Vigile du régime. Il patrouille ; s'il voit Akan faire quelque chose d'interdit, il
## doute (« ? »), puis donne l'alerte (« ! ») : il court au dernier endroit où il l'a vu,
## frappe s'il l'attrape, cherche s'il l'a perdu, puis retourne à sa ronde.
##
## Couches : percevoir (think, quelques fois par seconde) → décider (états) → chemin
## (NavGrid, gardé en mémoire) → avancer (_physics_process) → animer (CharacterVisual).

enum State { PATROL, SUSPICIOUS, ALERT, SEARCH, RETURN, KNOCKED_OUT }

const GROUP := &"enemy"
const WALK_SPEED := 1.8
## Plus lent qu'Akan en course : on peut le semer.
const RUN_SPEED := 4.6
const ACCELERATION := 20.0
const EYE_HEIGHT := 1.6
const SIGHT_RANGE_DAY := 10.0
const SIGHT_RANGE_NIGHT := 7.0
const HALF_ANGLE_DEGREES := 55.0
## Sur ses gardes, il regarde plus large.
const ALERT_HALF_ANGLE_DEGREES := 75.0
const THINK_SECONDS := 0.15
const WAYPOINT_RADIUS := 0.4
const ARRIVAL_RADIUS := 1.0
const PAUSE_SECONDS := 1.5
## Revenu au calme depuis tant de secondes, il reprend sa ronde.
const CALM_SECONDS := 2.0
const SEARCH_SECONDS := 6.0
const SEARCH_TURN_SPEED := 1.5
## Les Vigiles à cette distance d'un signalement (radio) accourent.
const RADIO_RADIUS := 35.0
const ATTACK_RANGE := 1.4
const ATTACK_COOLDOWN := 1.0
const ATTACK_DAMAGE := 12.0
const MAX_HEALTH := 60.0
const REPATH_SECONDS := 0.5
const REPATH_DISTANCE := 1.5
const STUCK_SECONDS := 2.0
const STUCK_PROGRESS := 0.5
const MIN_STATE_SECONDS := 0.4
const BODY_RADIUS := 0.3
const BODY_HEIGHT := 1.75
const INDICATOR_HEIGHT := 2.3
const FONT := preload("res://assets/fonts/Tiny5-Regular.ttf")
const NIGHT_THRESHOLD := 0.5

var state := State.PATROL
var id := ""
var patrol: Array[Vector3] = []
var grid: NavGrid
var nav: ZoneNavData
var awareness := Awareness.new()
var health := MAX_HEALTH
var visual := CharacterVisual.new()

## Le dernier endroit où il a vu (ou cru voir) Akan.
var _target := Vector3.INF
var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _patrol_index := 0
var _pause := 0.0
var _state_time := 0.0
var _calm_time := 0.0
var _attack_cooldown := 0.0
var _since_think := 0.0
var _since_repath := 0.0
var _stuck_time := 0.0
var _stuck_best := INF
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _indicator := Label3D.new()


## Crée le Vigile décrit par une entrée « vigiles » d'un lieu : {"id", "character"}.
## Sa ronde (patrol), sa grille (grid, nav) sont posées par le lieu.
static func create(definition: Dictionary) -> Vigile:
	var vigile := Vigile.new()
	vigile.id = definition.get("id", "")
	vigile.name = "Vigile%s" % vigile.id.to_pascal_case()
	vigile.visual.name = "Visual"
	vigile.visual.character_id = definition.get("character", "vigile")
	vigile.add_child(vigile.visual)
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = BODY_HEIGHT / 2.0
	vigile.add_child(shape)
	return vigile


func _ready() -> void:
	add_to_group(GROUP)
	_indicator.font = FONT
	_indicator.font_size = 8
	_indicator.pixel_size = 1.0 / 16.0
	_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_indicator.no_depth_test = true
	_indicator.outline_size = 2
	_indicator.position.y = INDICATOR_HEIGHT
	add_child(_indicator)
	EventBus.player_spotted.connect(_on_player_spotted)
	_show_state()


func _physics_process(delta: float) -> void:
	_since_think += delta
	if _since_think >= THINK_SECONDS:
		think(_since_think)
		_since_think = 0.0
	_move(delta)


## Perçoit et décide (sans bouger) : appelée quelques fois par seconde.
func think(delta: float) -> void:
	_state_time += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if state == State.KNOCKED_OUT:
		return
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	var seen := player != null and _sees(player.global_position)
	match state:
		State.PATROL, State.SUSPICIOUS, State.RETURN:
			_watch(player, seen, delta)
		State.ALERT:
			if seen:
				_target = player.global_position
				if _flat_distance(_target) <= ATTACK_RANGE and _attack_cooldown <= 0.0:
					_attack()
			elif _flat_distance(_target) <= ARRIVAL_RADIUS:
				_change(State.SEARCH)
		State.SEARCH:
			if seen:
				alert(player.global_position)
			elif _state_time >= SEARCH_SECONDS:
				_change(State.RETURN)
	_show_state()


## Donne l'alerte à ce Vigile : il court vers `position`.
func alert(position: Vector3) -> void:
	if state == State.KNOCKED_OUT:
		return
	_target = position
	awareness.value = 1.0
	if state != State.ALERT:
		_change(State.ALERT)


## Un coup reçu : il perd de la santé, et sait d'où il vient.
func take_hit(damage: float, from: Vector3) -> void:
	if state == State.KNOCKED_OUT:
		return
	health = maxf(health - damage, 0.0)
	if health <= 0.0:
		knock_out()
	else:
		alert(from)


## Hors d'état : à terre, il ne voit ni n'entend plus rien.
func knock_out() -> void:
	health = 0.0
	_change(State.KNOCKED_OUT)
	visual.knocked_out = true
	velocity = Vector3.ZERO
	EventBus.enemy_knocked_out.emit(id)


## Vrai si Akan, en `from`, peut le neutraliser d'un coup : par derrière, sans être repéré.
func can_be_taken_down(from: Vector3) -> bool:
	var unaware := (
		state in [State.PATROL, State.RETURN]
		or (state == State.SUSPICIOUS and not awareness.is_alerted())
	)
	return unaware and Combat.is_behind(global_position, visual.global_rotation.y, from)


# En ronde ou dans le doute : la jauge d'attention monte s'il voit Akan faire le mal.
func _watch(player: Player, seen: bool, delta: float) -> void:
	var suspicious := seen and GameState.is_offending()
	if suspicious:
		_target = player.global_position
	var distance := _flat_distance(player.global_position) if player != null else INF
	var crouched := player != null and player.crouched
	awareness.update(delta, suspicious, distance, _sight_range(), crouched)
	if awareness.is_alerted():
		GameState.surveillance.report(GameState.territory_id, 1.0)
		EventBus.sound_requested.emit(&"vigile_alerte")
		EventBus.player_spotted.emit(_target, id)
		alert(_target)
	elif awareness.is_suspicious() and state != State.SUSPICIOUS:
		_change(State.SUSPICIOUS)
	elif state == State.SUSPICIOUS:
		_calm_time = 0.0 if awareness.is_suspicious() else _calm_time + delta
		if _calm_time >= CALM_SECONDS and _state_time >= MIN_STATE_SECONDS:
			_change(State.RETURN)


func _sees(target: Vector3) -> bool:
	var eye := global_position + Vector3.UP * EYE_HEIGHT
	var half := (
		ALERT_HALF_ANGLE_DEGREES if state in [State.ALERT, State.SEARCH] else HALF_ANGLE_DEGREES
	)
	return Vision.can_see(
		eye, visual.global_rotation.y, deg_to_rad(half), _sight_range(), target, nav
	)


func _sight_range() -> float:
	var night := GameState.clock.night_factor() >= NIGHT_THRESHOLD
	return SIGHT_RANGE_NIGHT if night else SIGHT_RANGE_DAY


func _attack() -> void:
	_attack_cooldown = ATTACK_COOLDOWN
	var to := _target - global_position
	visual.rotation.y = atan2(-to.x, -to.z)
	visual.punch()
	GameState.vitals.damage(ATTACK_DAMAGE)


func _change(next: State) -> void:
	state = next
	_state_time = 0.0
	_calm_time = 0.0
	_path = PackedVector3Array()
	_path_goal = Vector3.INF
	# Rentré de son alerte, il repart l'esprit tranquille.
	if next in [State.PATROL, State.RETURN]:
		awareness.value = 0.0
	_show_state()


func _on_player_spotted(position: Vector3, source: String) -> void:
	if source != id and _flat_distance(position) <= RADIO_RADIUS:
		alert(position)


# --- Déplacement ------------------------------------------------------------


func _move(delta: float) -> void:
	var wanted := Vector3.ZERO
	match state:
		State.PATROL:
			wanted = _patrol_velocity(delta)
		State.SUSPICIOUS:
			_face(_target, delta)
		State.ALERT:
			wanted = _follow(_target, RUN_SPEED, delta)
		State.SEARCH:
			visual.rotation.y += SEARCH_TURN_SPEED * delta
		State.RETURN:
			var home := _nearest_patrol_point()
			wanted = _follow(home, WALK_SPEED, delta)
			if _flat_distance(home) <= ARRIVAL_RADIUS:
				_change(State.PATROL)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(wanted, ACCELERATION * delta)
	velocity = Vector3(horizontal.x, velocity.y - _gravity * delta, horizontal.z)
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	if state != State.KNOCKED_OUT and state != State.SEARCH:
		visual.animate(horizontal, delta)


func _patrol_velocity(delta: float) -> Vector3:
	if patrol.is_empty():
		return Vector3.ZERO
	if _pause > 0.0:
		_pause -= delta
		return Vector3.ZERO
	var goal := patrol[_patrol_index % patrol.size()]
	if _flat_distance(goal) <= ARRIVAL_RADIUS:
		_pause = PAUSE_SECONDS if patrol.size() > 1 else INF
		_patrol_index = (_patrol_index + 1) % patrol.size()
		return Vector3.ZERO
	return _follow(goal, WALK_SPEED, delta)


# Suit le chemin vers `goal` (recalculé si la cible a bougé, ou s'il piétine).
func _follow(goal: Vector3, speed: float, delta: float) -> Vector3:
	if not goal.is_finite():
		return Vector3.ZERO
	_since_repath += delta
	var moved := _path_goal.is_finite() and _path_goal.distance_to(goal) > REPATH_DISTANCE
	if _path.is_empty() or moved or (_since_repath >= REPATH_SECONDS and state == State.ALERT):
		_repath(goal)
	if _path_index >= _path.size():
		return Vector3.ZERO
	var next := _path[_path_index]
	var offset := Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
	if offset.length() <= maxf(WAYPOINT_RADIUS, speed * delta):
		_path_index += 1
		_stuck_best = INF
		return (
			offset / maxf(delta, 0.001)
			if _path_index >= _path.size()
			else offset.normalized() * speed
		)
	_check_stuck(offset.length(), goal, delta)
	return offset.normalized() * speed


func _repath(goal: Vector3) -> void:
	_since_repath = 0.0
	_path_goal = goal
	_path_index = 0
	_stuck_time = 0.0
	_stuck_best = INF
	_path = grid.path(global_position, goal) if grid != null else PackedVector3Array([goal])
	# La première case est celle où il se tient déjà.
	if _path.size() > 1 and _flat_distance(_path[0]) <= WAYPOINT_RADIUS * 2.0:
		_path_index = 1


# Pas de progrès vers la prochaine case depuis STUCK_SECONDS : on refait le chemin.
func _check_stuck(distance: float, goal: Vector3, delta: float) -> void:
	if distance < _stuck_best - STUCK_PROGRESS:
		_stuck_best = distance
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time >= STUCK_SECONDS:
		_repath(goal)


func _face(point: Vector3, delta: float) -> void:
	if not point.is_finite():
		return
	var to := point - global_position
	var wanted := atan2(-to.x, -to.z)
	visual.rotation.y = lerp_angle(
		visual.rotation.y, wanted, minf(1.0, CharacterVisual.TURN_SPEED * delta)
	)


func _nearest_patrol_point() -> Vector3:
	var best := global_position
	var best_distance := INF
	for point: Vector3 in patrol:
		if _flat_distance(point) < best_distance:
			best_distance = _flat_distance(point)
			best = point
	return best


func _flat_distance(point: Vector3) -> float:
	if not point.is_finite():
		return INF
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()


func _show_state() -> void:
	var palette := Palette.load_colors()
	var alerted := state == State.ALERT
	_indicator.visible = state in [State.SUSPICIOUS, State.ALERT, State.SEARCH]
	_indicator.text = "!" if alerted else "?"
	_indicator.modulate = palette["rouge_propagande" if alerted else "jaune_linge"]
