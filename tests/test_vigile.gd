extends GutTest
## Les Vigiles : patrouille, soupçon, alerte, recherche, retour ; coups et mise hors d'état.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")
const STEP := 0.1

var _nav: ZoneNavData
var _grid: NavGrid
var _player: Player


func before_each() -> void:
	GameState.new_game()
	GameState.enter("zone:grigny2", "grigny2")
	_nav = ZoneNavData.create(Vector2(60.0, 60.0))
	_grid = NavGrid.new(_nav)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector3(0.0, 0.05, 25.0)
	add_child_autofree(_player)


func after_each() -> void:
	GameState.new_game()


func test_a_patrol_walks_from_waypoint_to_waypoint() -> void:
	var vigile := _make([Vector3(-10.0, 0.0, -10.0), Vector3(10.0, 0.0, -10.0)])
	assert_eq(vigile.state, Vigile.State.PATROL)
	await wait_seconds(5.0)
	assert_gt(vigile.global_position.x, -9.0, "il avance vers le second point")


func test_an_honest_passer_by_is_ignored() -> void:
	var vigile := _make([Vector3(0.0, 0.0, 0.0)])
	_player.teleport(Vector3(0.0, 0.05, -4.0))
	_think(vigile, 3.0)
	assert_eq(vigile.state, Vigile.State.PATROL)


func test_an_offence_in_sight_makes_him_suspicious_then_alerted() -> void:
	var vigile := _make([Vector3(0.0, 0.0, 0.0)])
	_player.teleport(Vector3(0.0, 0.05, -6.0))
	GameState.commit_offence()
	_think(vigile, STEP * 2)
	assert_eq(vigile.state, Vigile.State.SUSPICIOUS, "d'abord le doute")
	watch_signals(EventBus)
	_think(vigile, 3.0)
	assert_eq(vigile.state, Vigile.State.ALERT)
	assert_eq(GameState.surveillance.level("grigny2"), 1)
	assert_signal_emitted(EventBus, "player_spotted")


func test_losing_sight_leads_to_a_search_then_back_to_the_patrol() -> void:
	var vigile := _make([Vector3(0.0, 0.0, 0.0)])
	vigile.alert(Vector3(0.0, 0.0, -3.0))
	_player.teleport(Vector3(20.0, 0.05, 25.0))
	await wait_seconds(3.0)
	_think(vigile, 0.5)
	assert_eq(vigile.state, Vigile.State.SEARCH, "arrivé là où il l'a vu, il cherche")
	_think(vigile, Vigile.SEARCH_SECONDS + 0.5)
	assert_eq(vigile.state, Vigile.State.RETURN)


func test_a_camera_report_brings_nearby_vigiles() -> void:
	var near := _make([Vector3(0.0, 0.0, 0.0)])
	var far := _make([Vector3(0.0, 0.0, 0.0)])
	far.global_position = Vector3(500.0, 0.0, 0.0)
	EventBus.player_spotted.emit(Vector3(5.0, 0.0, 5.0), "camera")
	assert_eq(near.state, Vigile.State.ALERT)
	assert_eq(far.state, Vigile.State.PATROL, "trop loin pour entendre la radio")


func test_three_punches_knock_him_out_and_a_takedown_from_behind_is_instant() -> void:
	var vigile := _make([Vector3(0.0, 0.0, 0.0)])
	for i: int in 3:
		vigile.take_hit(Combat.PUNCH_DAMAGE, _player.global_position)
	assert_eq(vigile.state, Vigile.State.KNOCKED_OUT)
	var other := _make([Vector3(5.0, 0.0, 0.0)])
	other.knock_out()
	assert_eq(other.state, Vigile.State.KNOCKED_OUT)
	GameState.commit_offence()
	_player.teleport(Vector3(0.0, 0.05, -2.0))
	_think(vigile, 3.0)
	assert_eq(vigile.state, Vigile.State.KNOCKED_OUT, "à terre, il ne voit plus rien")


func test_an_alerted_vigile_hits_akan_in_reach() -> void:
	var vigile := _make([Vector3(0.0, 0.0, 0.0)])
	_player.teleport(Vector3(0.0, 0.05, -1.0))
	vigile.alert(_player.global_position)
	_think(vigile, Vigile.ATTACK_COOLDOWN * 2.5)
	assert_lt(GameState.vitals.health, Vitals.MAX_HEALTH)


func _make(patrol: Array[Vector3]) -> Vigile:
	var vigile := Vigile.create({"id": "essai", "character": "vigile"})
	vigile.grid = _grid
	vigile.nav = _nav
	vigile.patrol = patrol
	vigile.position = patrol[0] + Vector3.UP * 0.05
	add_child_autofree(vigile)
	return vigile


# Fait réfléchir le Vigile `seconds` secondes, par pas réguliers (perception et décision).
func _think(vigile: Vigile, seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		vigile.think(STEP)
		elapsed += STEP


func test_akan_punches_the_vigile_in_front_of_him() -> void:
	var vigile := _make([Vector3(0.0, 0.0, -1.0)])
	vigile.visual.rotation.y = PI
	_player.teleport(Vector3(0.0, 0.05, 0.0))
	_player.get_node("Visual").rotation.y = 0.0
	_player.attack()
	assert_eq(vigile.health, Vigile.MAX_HEALTH - Combat.PUNCH_DAMAGE, "face à face : un coup")
	assert_eq(vigile.state, Vigile.State.ALERT)
	assert_true(GameState.is_offending(), "frapper un Vigile est interdit")


func test_a_takedown_from_behind_is_silent_and_instant() -> void:
	var vigile := _make([Vector3(0.0, 0.0, -1.0)])
	vigile.visual.rotation.y = 0.0
	_player.teleport(Vector3(0.0, 0.05, 0.0))
	_player.get_node("Visual").rotation.y = 0.0
	_player.attack()
	assert_eq(vigile.state, Vigile.State.KNOCKED_OUT, "il regardait ailleurs")


func test_punching_the_air_hurts_nobody() -> void:
	var vigile := _make([Vector3(5.0, 0.0, 5.0)])
	_player.teleport(Vector3(0.0, 0.05, 0.0))
	_player.attack()
	assert_eq(vigile.health, Vigile.MAX_HEALTH)
	assert_false(GameState.is_offending())
