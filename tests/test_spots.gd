extends GutTest
## Les points d'action posés par les données : un geste, un dialogue, parfois un délit.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	get_tree().paused = false
	GameState.new_game()


func test_a_spot_opens_its_dialogue() -> void:
	var spot := Spot.create(
		{"id": "lit", "at": "default", "prompt": "PROMPT_DORMIR", "dialogue": ["akan", "dormir"]}
	)
	add_child_autofree(spot)
	assert_eq(spot.prompt, "PROMPT_DORMIR")
	watch_signals(EventBus)
	spot.interact(null)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["akan", "dormir"])


func test_a_spot_is_usable_only_while_its_condition_holds() -> void:
	var spot := Spot.create(
		{
			"id": "mur",
			"at": "default",
			"prompt": "PROMPT_TAGUER",
			"dialogue": ["pixel", "tag"],
			"if": {"hours": [21, 6]}
		}
	)
	add_child_autofree(spot)
	GameState.clock.minutes = 12 * 60.0
	spot.refresh()
	assert_false(spot.enabled, "de jour, trop risqué")
	GameState.clock.minutes = 22 * 60.0
	spot.refresh()
	assert_true(spot.enabled)


func test_an_illegal_gesture_is_an_offence() -> void:
	var spot := Spot.create(
		{
			"id": "mur",
			"at": "default",
			"prompt": "PROMPT_TAGUER",
			"dialogue": ["pixel", "tag"],
			"offence": true
		}
	)
	add_child_autofree(spot)
	assert_false(GameState.is_offending())
	spot.interact(null)
	assert_true(GameState.is_offending())


func test_sleeping_moves_the_clock_to_the_chosen_hour_and_rests_the_body() -> void:
	var street := Neighbourhood.new()
	GameState.clock.minutes = 14 * 60.0
	GameState.vitals.damage(40.0)
	var day := GameState.clock.day
	street.sleep_until(21)
	assert_eq(GameState.clock.hour(), 21)
	assert_eq(GameState.clock.day, day)
	assert_eq(GameState.vitals.health, Vitals.MAX_HEALTH, "une nuit répare")
	street.sleep_until(7)
	assert_eq(GameState.clock.hour(), 7)
	assert_eq(GameState.clock.day, day + 1)


func test_places_install_their_spots() -> void:
	var home := Zone.create("appartement_akan")
	add_child_autofree(home)
	await wait_process_frames(2)
	var bed := home.get_node_or_null("SpotLit") as Spot
	assert_not_null(bed)
	assert_eq(bed.dialogue, ["akan", "dormir"])
	var at := bed.global_position
	assert_lt(
		at.distance_to(home.marker_position("default")), 2.0, "le lit est dans la chambre d'Akan"
	)


func test_the_ration_point_is_open_by_day_only() -> void:
	GameState.clock.minutes = 10 * 60.0
	var day := Zone.create("grigny2@point_ration")
	add_child_autofree(day)
	await wait_process_frames(2)
	assert_not_null(day.get_node_or_null("VigileRation"))
	day.free()
	GameState.clock.minutes = 22 * 60.0
	var night := Zone.create("grigny2@point_ration")
	add_child_autofree(night)
	await wait_process_frames(2)
	assert_null(night.get_node_or_null("VigileRation"), "fermé la nuit")
	assert_null(night.get_node_or_null("VoisineFile"))


func test_a_spot_opens_as_soon_as_its_step_comes() -> void:
	GameState.quests = QuestLog.new(
		{
			"essai":
			{
				"id": "essai",
				"steps":
				[
					{"id": "a", "type": "TALK", "target": "x"},
					{"id": "b", "type": "TALK", "target": "y"}
				]
			}
		}
	)
	GameState.connect_quests()
	GameState.quests.start("essai")
	var spot := Spot.create(
		{
			"id": "boite",
			"at": "default",
			"prompt": "PROMPT_FOUILLER",
			"dialogue": ["tour", "boites"],
			"if": {"step": "essai:b"}
		}
	)
	add_child_autofree(spot)
	assert_false(spot.enabled)
	GameState.objective("TALK", "x")
	assert_true(spot.enabled, "sans attendre la relecture périodique")
