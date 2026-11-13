extends GutTest

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")


func before_each() -> void:
	GameState.new_game()


func test_an_npc_has_a_body_a_model_and_something_to_say() -> void:
	var npc := Npc.create({"id": "mere", "character": "daronne", "dialogue": "daronne"})
	add_child_autofree(npc)
	assert_eq(npc.name, "Mere")
	assert_eq(npc.prompt, "PROMPT_PARLER")
	assert_true(npc.enabled)
	assert_true(npc.visual.has_model())
	assert_eq(npc.find_children("*", "CollisionShape3D", true, false).size(), 1)


func test_an_npc_without_dialogue_is_only_part_of_the_scenery() -> void:
	var npc := Npc.create({"id": "passant", "character": "civil_1"})
	add_child_autofree(npc)
	assert_false(npc.enabled)


func test_talking_turns_the_npc_towards_akan_and_asks_for_the_dialogue() -> void:
	var npc := Npc.create(
		{"id": "mere", "character": "daronne", "dialogue": "daronne", "cue": "matin"}
	)
	add_child_autofree(npc)
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = Vector3(2.0, 0.0, 0.0)
	add_child_autofree(player)
	watch_signals(EventBus)
	npc.interact(player)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["daronne", "matin"])
	assert_almost_eq(npc.visual.rotation.y, -PI / 2.0, 0.01, "tourné vers l'est, où se tient Akan")


func test_a_zone_places_its_npcs_when_their_condition_holds() -> void:
	var home := Zone.create("appartement_akan")
	add_child_autofree(home)
	await wait_physics_frames(2)
	var npcs := home.find_children("*", "Npc", true, false)
	assert_gt(npcs.size(), 0)
	var mother: Npc = home.get_node("Daronne")
	assert_eq(mother.character_id, "daronne")
	assert_lt(mother.global_position.distance_to(home.marker_position("daronne")), 0.1)
	assert_gt(
		mother.global_position.distance_to(home.player.global_position), 0.9, "pas l'un sur l'autre"
	)


func test_an_npc_looks_at_akan_when_he_comes_near() -> void:
	var npc := Npc.create({"id": "mere", "character": "daronne", "dialogue": "daronne"})
	add_child_autofree(npc)
	var player: Player = PLAYER_SCENE.instantiate()
	player.position = Vector3(2.0, 0.0, 0.0)
	add_child_autofree(player)
	await wait_process_frames(20)
	assert_lt(npc.visual.get_part("Head").rotation.y, -0.3, "elle tourne la tête vers lui")
	player.position = Vector3(20.0, 0.0, 0.0)
	await wait_process_frames(40)
	assert_almost_eq(npc.visual.get_part("Head").rotation.y, 0.0, 0.05)


func test_talking_animates_the_npc_even_while_the_game_is_paused() -> void:
	var npc := Npc.create({"id": "mere", "character": "daronne", "dialogue": "daronne"})
	add_child_autofree(npc)
	npc.interact(null)
	assert_true(npc.visual.talking)
	assert_eq(npc.visual.process_mode, Node.PROCESS_MODE_ALWAYS)
	EventBus.dialogue_ended.emit("daronne")
	assert_false(npc.visual.talking)
	assert_eq(npc.visual.process_mode, Node.PROCESS_MODE_INHERIT)
