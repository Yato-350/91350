extends GutTest


func before_each() -> void:
	GameState.new_game()
	GameState.enter("zone:grigny2", "grigny2")


func test_an_empty_condition_is_true() -> void:
	assert_true(Conditions.check({}))


func test_flags_must_be_set_or_absent() -> void:
	GameState.set_flag("radio")
	assert_true(Conditions.check({"flags": ["radio"]}))
	assert_false(Conditions.check({"flags": ["radio", "carte"]}))
	assert_true(Conditions.check({"not_flags": ["carte"]}))
	assert_false(Conditions.check({"not_flags": ["radio"]}))


func test_items_must_be_in_the_bag() -> void:
	GameState.give("piles", 2)
	assert_true(Conditions.check({"items": {"piles": 2}}))
	assert_false(Conditions.check({"items": {"piles": 3}}))


func test_hours_wrap_around_midnight() -> void:
	GameState.clock.minutes = 22 * 60.0
	assert_true(Conditions.check({"hours": [21, 6]}))
	assert_false(Conditions.check({"hours": [8, 20]}))
	GameState.clock.minutes = 5 * 60.0
	assert_true(Conditions.check({"hours": [21, 6]}))
	GameState.clock.minutes = 6 * 60.0
	assert_false(Conditions.check({"hours": [21, 6]}))
	assert_true(Conditions.check({"hours": [6, 7]}))


func test_status_and_reputation_bounds() -> void:
	assert_true(Conditions.check({"status_max": 0}))
	GameState.surveillance.report("grigny2", 3.0)
	assert_false(Conditions.check({"status_max": 0}))
	assert_true(Conditions.check({"status_max": 1}))
	GameState.progression.add_reputation("familles", 10)
	assert_true(Conditions.check({"reputation": {"familles": 10}}))
	assert_false(Conditions.check({"reputation": {"familles": 11}}))


func test_every_key_must_hold() -> void:
	GameState.set_flag("radio")
	assert_false(Conditions.check({"flags": ["radio"], "items": {"piles": 1}}))
	GameState.give("piles", 1)
	assert_true(Conditions.check({"flags": ["radio"], "items": {"piles": 1}}))
