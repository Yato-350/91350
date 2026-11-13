extends GutTest


func test_vigilance_rises_by_reports_and_is_capped_at_five() -> void:
	var surveillance := Surveillance.new()
	watch_signals(surveillance)
	surveillance.report("grigny2", 1.0)
	assert_eq(surveillance.level("grigny2"), 1)
	assert_signal_emitted_with_parameters(surveillance, "vigilance_changed", ["grigny2", 1])
	surveillance.report("grigny2", 9.0)
	assert_eq(surveillance.level("grigny2"), Surveillance.MAX_LEVEL)
	assert_eq(surveillance.level("ailleurs"), 0)


func test_vigilance_decays_only_while_hidden() -> void:
	var surveillance := Surveillance.new()
	surveillance.report("grigny2", 2.0)
	surveillance.tick("grigny2", Surveillance.DECAY_SECONDS * 0.5, false)
	assert_eq(surveillance.level("grigny2"), 2, "à découvert, rien ne redescend")
	surveillance.tick("grigny2", Surveillance.DECAY_SECONDS, true)
	assert_eq(surveillance.level("grigny2"), 1)
	surveillance.tick("grigny2", Surveillance.DECAY_SECONDS * 5.0, true)
	assert_eq(surveillance.level("grigny2"), 0)


func test_citizen_status_follows_the_worst_vigilance_and_never_drops_by_itself() -> void:
	var surveillance := Surveillance.new()
	assert_eq(surveillance.status, Surveillance.Status.CONFORME)
	surveillance.report("grigny2", 3.0)
	assert_eq(surveillance.status, Surveillance.Status.SURVEILLE)
	surveillance.report("grigny2", 2.0)
	assert_eq(surveillance.status, Surveillance.Status.ENNEMI_PUBLIC)
	surveillance.tick("grigny2", 1000.0, true)
	assert_eq(surveillance.status, Surveillance.Status.ENNEMI_PUBLIC)
	surveillance.lower_status()
	assert_eq(surveillance.status, Surveillance.Status.FICHE)


func test_surveillance_round_trips() -> void:
	var surveillance := Surveillance.new()
	surveillance.report("grigny2", 3.4)
	var copy := Surveillance.new()
	copy.from_dict(surveillance.to_dict())
	assert_eq(copy.level("grigny2"), 3)
	assert_eq(copy.status, Surveillance.Status.SURVEILLE)


func test_experience_gives_levels_and_skill_points() -> void:
	var progression := Progression.new()
	watch_signals(progression)
	progression.add_xp(Progression.xp_for_level(2) - 1)
	assert_eq(progression.level, 1)
	progression.add_xp(1)
	assert_eq(progression.level, 2)
	assert_eq(progression.skill_points, 1)
	assert_signal_emitted_with_parameters(progression, "leveled_up", [2])
	progression.add_xp(Progression.xp_for_level(4))
	assert_gte(progression.level, 4)


func test_skills_cost_points_and_unlock_in_order() -> void:
	var progression := Progression.new()
	assert_false(progression.learn("discretion"), "pas de point")
	progression.skill_points = 2
	assert_true(progression.learn("discretion"))
	assert_true(progression.learn("discretion"))
	assert_eq(progression.skill_level("discretion"), 2)
	assert_eq(progression.skill_points, 0)
	assert_false(progression.learn("magie"))
	progression.skill_points = 9
	for i: int in 5:
		progression.learn("combat")
	assert_eq(progression.skill_level("combat"), Progression.MAX_SKILL_LEVEL)


func test_reputation_is_clamped_per_group_and_round_trips() -> void:
	var progression := Progression.new()
	progression.add_reputation("familles", 15)
	progression.add_reputation("reseau", -250)
	assert_eq(progression.reputation("familles"), 15)
	assert_eq(progression.reputation("reseau"), -100)
	assert_eq(progression.reputation("inconnu"), 0)
	var copy := Progression.new()
	copy.from_dict(progression.to_dict())
	assert_eq(copy.reputation("familles"), 15)


func test_a_spotted_akan_stays_hot_for_a_while() -> void:
	var surveillance := Surveillance.new()
	assert_false(surveillance.is_hot(100.0))
	surveillance.note_spotted(100.0)
	assert_true(surveillance.is_hot(100.0 + Surveillance.HOT_SECONDS - 1.0))
	assert_false(surveillance.is_hot(100.0 + Surveillance.HOT_SECONDS + 1.0))
