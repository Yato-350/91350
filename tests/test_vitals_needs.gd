extends GutTest


func test_running_drains_stamina_and_rest_restores_it_after_a_delay() -> void:
	var vitals := Vitals.new()
	vitals.tick(2.0, true, false)
	assert_almost_eq(vitals.stamina, 80.0, 0.01)
	vitals.tick(0.5, false, false)
	assert_almost_eq(vitals.stamina, 80.0, 0.01, "pas de récupération avant le délai")
	vitals.tick(Vitals.REGEN_DELAY, false, false)
	vitals.tick(1.0, false, false)
	assert_gt(vitals.stamina, 80.0)


func test_exhausted_runner_must_recover_before_running_again() -> void:
	var vitals := Vitals.new()
	vitals.tick(20.0, true, false)
	assert_eq(vitals.stamina, 0.0)
	assert_false(vitals.can_run())
	vitals.tick(Vitals.REGEN_DELAY + 0.5, false, false)
	assert_false(vitals.can_run(), "encore essoufflé")
	vitals.tick(3.0, false, false)
	assert_true(vitals.can_run())


func test_weakened_body_recovers_half_as_fast() -> void:
	var fit := Vitals.new()
	var weak := Vitals.new()
	for vitals: Vitals in [fit, weak]:
		vitals.tick(5.0, true, false)
		vitals.tick(Vitals.REGEN_DELAY, false, false)
	fit.tick(1.0, false, false)
	weak.tick(1.0, false, true)
	assert_almost_eq(weak.stamina - 50.0, (fit.stamina - 50.0) * 0.5, 0.01)


func test_damage_and_heal_are_clamped_and_death_is_signalled_once() -> void:
	var vitals := Vitals.new()
	watch_signals(vitals)
	vitals.damage(30.0)
	vitals.heal(500.0)
	assert_eq(vitals.health, Vitals.MAX_HEALTH)
	vitals.damage(150.0)
	vitals.damage(10.0)
	assert_eq(vitals.health, 0.0)
	assert_true(vitals.is_down())
	assert_signal_emit_count(vitals, "downed", 1)


func test_needs_fall_with_time_and_faster_when_running() -> void:
	var idle := Needs.new()
	var runner := Needs.new()
	idle.tick(60.0, false)
	runner.tick(60.0, true)
	assert_almost_eq(idle.thirst, 100.0 - Needs.THIRST_PER_MINUTE, 0.01)
	assert_almost_eq(idle.hunger, 100.0 - Needs.HUNGER_PER_MINUTE, 0.01)
	assert_almost_eq(runner.thirst, 100.0 - Needs.THIRST_PER_MINUTE * Needs.RUN_FACTOR, 0.01)


func test_eating_and_drinking_are_clamped() -> void:
	var needs := Needs.new()
	needs.thirst = 20.0
	needs.hunger = 95.0
	needs.drink(35.0)
	needs.eat(30.0)
	assert_eq(needs.thirst, 55.0)
	assert_eq(needs.hunger, Needs.MAX)


func test_starving_hurts_only_after_a_grace_period() -> void:
	var needs := Needs.new()
	needs.thirst = 0.0
	assert_true(needs.is_depleted())
	var early := needs.tick(Needs.GRACE_SECONDS - 1.0, false)
	assert_eq(early, 0.0, "une pression, pas une punition")
	var later := needs.tick(1.0 + Needs.DAMAGE_INTERVAL * 3.0, false)
	assert_almost_eq(later, Needs.DAMAGE_PER_INTERVAL * 3.0, 0.01)
	needs.drink(10.0)
	assert_eq(needs.tick(Needs.DAMAGE_INTERVAL * 2.0, false), 0.0, "boire remet le compteur à zéro")


func test_vitals_and_needs_round_trip_through_a_dictionary() -> void:
	var vitals := Vitals.new()
	vitals.damage(40.0)
	vitals.tick(3.0, true, false)
	var copy := Vitals.new()
	copy.from_dict(vitals.to_dict())
	assert_eq(copy.health, 60.0)
	assert_almost_eq(copy.stamina, 70.0, 0.01)
	var needs := Needs.new()
	needs.thirst = 12.0
	var other := Needs.new()
	other.from_dict(needs.to_dict())
	assert_eq(other.thirst, 12.0)
	other.from_dict({"thirst": "x"})
	assert_eq(other.thirst, 12.0, "une valeur mal formée est ignorée")
