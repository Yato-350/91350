extends GutTest


func before_each() -> void:
	GameState.new_game()
	GameState.territory_id = "grigny2"


func after_each() -> void:
	GameState.playing = false
	GameState.new_game()


func test_a_new_game_starts_fresh() -> void:
	assert_eq(GameState.vitals.health, Vitals.MAX_HEALTH)
	assert_eq(GameState.clock.day, 1)
	assert_eq(GameState.flags, {})
	assert_eq(GameState.inventory.count("bouteille_eau"), 0)
	assert_eq(GameState.territory.control("grigny2"), 85)
	assert_eq(GameState.location, "")


func test_flags_are_set_read_and_signalled() -> void:
	watch_signals(EventBus)
	assert_false(GameState.has_flag("radio"))
	GameState.set_flag("radio")
	assert_true(GameState.has_flag("radio"))
	assert_signal_emitted_with_parameters(EventBus, "flag_changed", ["radio"])
	GameState.set_flag("radio", false)
	assert_false(GameState.has_flag("radio"))


func test_giving_items_fills_the_bag_and_drops_the_rest() -> void:
	watch_signals(EventBus)
	GameState.give("bouteille_eau", 2)
	assert_eq(GameState.inventory.count("bouteille_eau"), 2)
	assert_signal_emitted_with_parameters(EventBus, "inventory_changed", ["bouteille_eau"])
	GameState.give("batte", 20)
	assert_eq(GameState.inventory.count("batte"), 11)
	assert_signal_emitted_with_parameters(EventBus, "item_dropped", ["batte", 9])


func test_using_food_and_water_restores_needs_and_consumes_the_item() -> void:
	GameState.needs.thirst = 10.0
	GameState.give("bouteille_eau", 1)
	assert_true(GameState.use_item("bouteille_eau"))
	assert_gt(GameState.needs.thirst, 10.0)
	assert_eq(GameState.inventory.count("bouteille_eau"), 0)
	assert_false(GameState.use_item("bouteille_eau"), "il n'y en a plus")
	GameState.give("piles", 1)
	assert_false(GameState.use_item("piles"), "des piles ne se mangent pas")
	assert_eq(GameState.inventory.count("piles"), 1)


func test_a_backpack_is_worn_when_used() -> void:
	GameState.give("sac_petit", 1)
	assert_true(GameState.use_item("sac_petit"))
	assert_eq(GameState.inventory.bag, "sac_petit")
	assert_eq(GameState.inventory.slots.size(), 20)
	assert_eq(GameState.inventory.count("sac_petit"), 0)


func test_effects_reward_the_player() -> void:
	(
		GameState
		. apply_effects(
			{
				"xp": 150,
				"skill_points": 1,
				"items": {"bouteille_eau": 2},
				"reputation": {"familles": 5},
				"support": 10,
				"control": -5,
				"vigilance": 1,
				"flags": ["radio"],
			}
		)
	)
	assert_eq(GameState.progression.level, 2)
	assert_eq(GameState.progression.skill_points, 2)
	assert_eq(GameState.inventory.count("bouteille_eau"), 2)
	assert_eq(GameState.progression.reputation("familles"), 5)
	assert_eq(GameState.territory.support("grigny2"), 25)
	assert_eq(GameState.territory.control("grigny2"), 80)
	assert_eq(GameState.surveillance.level("grigny2"), 1)
	assert_true(GameState.has_flag("radio"))


func test_effects_can_take_items_and_free_the_zone() -> void:
	watch_signals(EventBus)
	GameState.give("piles", 3)
	GameState.apply_effects({"take": {"piles": 2}, "liberate": true})
	assert_eq(GameState.inventory.count("piles"), 1)
	assert_true(GameState.territory.is_liberated("grigny2"))
	assert_signal_emitted_with_parameters(EventBus, "zone_liberated", ["grigny2"])


func test_hunger_and_thirst_hurt_through_the_body_tick() -> void:
	GameState.needs.thirst = 0.0
	GameState.tick_body(Needs.GRACE_SECONDS + Needs.DAMAGE_INTERVAL, false)
	assert_lt(GameState.vitals.health, Vitals.MAX_HEALTH)


func test_going_down_is_announced_on_the_bus() -> void:
	watch_signals(EventBus)
	GameState.vitals.damage(500.0)
	assert_signal_emitted(EventBus, "player_downed")


func test_the_clock_only_runs_while_playing() -> void:
	var start := GameState.clock.minutes
	await wait_process_frames(5)
	assert_eq(GameState.clock.minutes, start)
	GameState.playing = true
	await wait_process_frames(5)
	assert_gt(GameState.clock.minutes, start)


func test_a_whole_game_round_trips_through_a_save() -> void:
	GameState.give("bouteille_eau", 3)
	GameState.set_flag("radio")
	GameState.clock.advance(125.0)
	GameState.vitals.damage(30.0)
	GameState.needs.thirst = 42.0
	GameState.progression.add_xp(120)
	GameState.surveillance.report("grigny2", 2.0)
	GameState.territory.add_support("grigny2", 20)
	GameState.location = "zone:grigny2@gare"
	GameState.saved_position = [1.0, 0.0, -2.0]
	var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.save_state()))
	GameState.new_game()
	GameState.load_state(saved)
	assert_eq(GameState.inventory.count("bouteille_eau"), 3)
	assert_true(GameState.has_flag("radio"))
	assert_almost_eq(GameState.clock.minutes, GameClock.START_HOUR * 60.0 + 125.0, 0.01)
	assert_eq(GameState.vitals.health, 70.0)
	assert_eq(GameState.needs.thirst, 42.0)
	assert_eq(GameState.progression.level, 2)
	assert_eq(GameState.surveillance.level("grigny2"), 2)
	assert_eq(GameState.territory.support("grigny2"), 35)
	assert_eq(GameState.location, "zone:grigny2@gare")
	assert_eq(GameState.saved_position, [1.0, 0.0, -2.0])


func test_loading_an_old_or_partial_save_resets_what_is_missing() -> void:
	GameState.give("piles", 4)
	GameState.set_flag("radio")
	GameState.load_state({"flags": {"carte": true}, "position": ["x"]})
	assert_eq(GameState.inventory.count("piles"), 0)
	assert_false(GameState.has_flag("radio"))
	assert_true(GameState.has_flag("carte"))
	assert_eq(GameState.saved_position, [])


func test_game_state_is_written_by_the_save_manager() -> void:
	assert_true(GameState.is_in_group(SaveManager.SAVEABLE_GROUP))
	assert_eq(GameState.save_id, &"game")


func test_entering_a_place_is_announced() -> void:
	watch_signals(EventBus)
	GameState.enter("zone:hall_tour", "grigny2")
	assert_eq(GameState.location, "zone:hall_tour")
	assert_eq(GameState.territory_id, "grigny2")
	assert_signal_emitted(EventBus, "location_changed")
	assert_eq(GameState.place_id(), "hall_tour")
	GameState.enter("zone:grigny2@gare", "grigny2")
	assert_eq(GameState.place_id(), "grigny2")
	GameState.enter("res://scenes/zones/test_zone.tscn", "")
	assert_eq(GameState.place_id(), "")
