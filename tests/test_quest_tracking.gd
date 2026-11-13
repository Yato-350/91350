extends GutTest
## Le jeu valide seul les objectifs : lieux, repères, objets, repas, conversations.

const QUESTS := {
	"essai":
	{
		"id": "essai",
		"steps":
		[
			{"id": "hall", "type": "GOTO", "target": "hall_tour"},
			{"id": "boire", "type": "USE", "target": "boire"},
			{"id": "piles", "type": "COLLECT", "target": "piles", "count": 2},
			{
				"id": "parler",
				"type": "TALK",
				"target": "daronne",
				"dialogue": ["res://tests/dialogue/essai.dialogue", "suite"],
			},
			{"id": "sejour", "type": "GOTO", "target": "appartement_akan:sejour"},
		],
	},
}


func before_each() -> void:
	GameState.new_game()
	GameState.quests = QuestLog.new(QUESTS)
	GameState.connect_quests()
	GameState.quests.start("essai")


func after_each() -> void:
	get_tree().paused = false
	GameState.new_game()


func test_entering_a_place_reaches_it() -> void:
	GameState.enter("zone:palier_11", "grigny2")
	assert_true(GameState.quests.is_step("essai", "hall"))
	GameState.enter("zone:hall_tour@escalier", "grigny2")
	assert_true(GameState.quests.is_step("essai", "boire"))


func test_drinking_counts_as_using_and_owning_counts_as_collecting() -> void:
	GameState.quests.notify("GOTO", "hall_tour")
	GameState.give("piles", 2)
	assert_true(GameState.quests.is_step("essai", "boire"), "les piles attendent leur tour")
	GameState.give("bouteille_eau", 1)
	GameState.use_item("bouteille_eau")
	assert_true(GameState.quests.is_step("essai", "parler"), "déjà dans le sac : validé d'office")


func test_a_finished_step_can_start_a_dialogue() -> void:
	watch_signals(EventBus)
	GameState.quests.notify("GOTO", "hall_tour")
	GameState.quests.notify("USE", "boire")
	GameState.give("piles", 2)
	GameState.quests.notify("TALK", "daronne")
	assert_signal_emitted_with_parameters(
		EventBus, "dialogue_requested", ["res://tests/dialogue/essai.dialogue", "suite"]
	)


func test_a_conversation_with_an_npc_counts_as_talking_to_them() -> void:
	for step: Array in [["GOTO", "hall_tour"], ["USE", "boire"]]:
		GameState.quests.notify(step[0], step[1])
	GameState.give("piles", 2)
	var npc := Npc.create({"id": "daronne", "character": "daronne", "dialogue": "daronne"})
	add_child_autofree(npc)
	npc.interact(null)
	EventBus.dialogue_ended.emit("daronne")
	assert_true(GameState.quests.is_step("essai", "sejour"))


func test_reaching_a_marker_reaches_it() -> void:
	for step: Array in [["GOTO", "hall_tour"], ["USE", "boire"]]:
		GameState.quests.notify(step[0], step[1])
	GameState.give("piles", 2)
	GameState.quests.notify("TALK", "daronne")
	assert_true(GameState.quests.is_step("essai", "sejour"))
	var home := Zone.create("appartement_akan")
	add_child_autofree(home)
	await wait_physics_frames(2)
	assert_true(GameState.quests.is_active("essai"))
	home.player.teleport(home.marker_position("sejour") + Vector3.UP * 0.1)
	await wait_physics_frames(3)
	assert_true(GameState.quests.is_done("essai"))
