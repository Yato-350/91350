extends GutTest


func test_a_day_lasts_twenty_four_real_minutes() -> void:
	var clock := GameClock.new()
	var start := clock.minutes
	clock.advance(60.0)
	assert_almost_eq(clock.minutes - start, 60.0, 0.01, "une minute réelle = une heure de jeu")
	clock.advance(24.0 * 60.0)
	assert_eq(clock.day, 2)
	assert_almost_eq(clock.minutes, start + 60.0, 0.01)


func test_clock_reads_hours_and_formats_time() -> void:
	var clock := GameClock.new()
	clock.minutes = 20 * 60.0 + 52.0
	assert_eq(clock.hour(), 20)
	assert_eq(clock.format(), "20:52")


func test_night_factor_is_zero_at_noon_and_one_at_midnight() -> void:
	var clock := GameClock.new()
	clock.minutes = 12 * 60.0
	assert_eq(clock.night_factor(), 0.0)
	clock.minutes = 0.0
	assert_eq(clock.night_factor(), 1.0)
	clock.minutes = GameClock.DUSK_HOUR * 60.0
	assert_between(clock.night_factor(), 0.01, 0.99)


func test_curfew_runs_from_nine_to_six_and_can_be_brought_forward() -> void:
	var clock := GameClock.new()
	clock.minutes = 20 * 60.0 + 30.0
	assert_false(clock.is_curfew())
	assert_true(clock.is_curfew(1), "couvre-feu avancé d'une heure")
	clock.minutes = 21 * 60.0
	assert_true(clock.is_curfew())
	clock.minutes = 5 * 60.0 + 59.0
	assert_true(clock.is_curfew())
	clock.minutes = 6 * 60.0
	assert_false(clock.is_curfew())


func test_territory_tracks_control_and_support_per_zone() -> void:
	var territory := Territory.new()
	territory.register("grigny2", 85, 15)
	territory.add_support("grigny2", 30)
	territory.add_control("grigny2", -200)
	assert_eq(territory.support("grigny2"), 45)
	assert_eq(territory.control("grigny2"), 0)
	assert_false(territory.can_liberate("grigny2"), "soutien insuffisant")
	territory.add_support("grigny2", 30)
	assert_true(territory.can_liberate("grigny2"))


func test_liberation_is_signalled_once_and_survives_a_save() -> void:
	var territory := Territory.new()
	territory.register("grigny2", 20, 80)
	watch_signals(territory)
	assert_true(territory.liberate("grigny2"))
	assert_false(territory.liberate("grigny2"))
	assert_signal_emit_count(territory, "liberated", 1)
	var copy := Territory.new()
	copy.register("grigny2", 85, 15)
	copy.from_dict(territory.to_dict())
	assert_true(copy.is_liberated("grigny2"))
	assert_eq(copy.support("grigny2"), 80)
	assert_false(copy.is_liberated("inconnue"))


func test_the_clock_counts_the_minutes_until_an_hour_comes_round() -> void:
	var clock := GameClock.new()
	clock.minutes = 14 * 60.0
	assert_eq(clock.minutes_until(21), 7 * 60.0)
	assert_eq(clock.minutes_until(7), 17 * 60.0, "demain matin")
	assert_eq(clock.minutes_until(14), 0.0)


func test_the_regime_greys_its_zones_and_freedom_brings_the_colour_back() -> void:
	var territory := Territory.new()
	territory.register("grigny2", 85, 15)
	assert_eq(territory.saturation("grigny2"), Territory.REGIME_SATURATION)
	assert_lt(Territory.REGIME_SATURATION, 1.0)
	territory.liberate("grigny2")
	assert_eq(territory.saturation("grigny2"), 1.0)
	assert_eq(territory.saturation(""), 1.0, "hors territoire : pleine couleur")
