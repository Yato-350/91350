extends GutTest
## Le jour et la nuit : lumière selon l'heure, lampadaires la nuit, couvre-feu annoncé.


func before_each() -> void:
	GameState.new_game()


func after_each() -> void:
	GameState.new_game()


func test_noon_is_bright_and_midnight_is_dark_and_blue() -> void:
	var noon := DayLight.sample(12.0 * 60.0)
	var midnight := DayLight.sample(0.0)
	assert_gt(noon["sun_energy"], 0.7)
	assert_eq(midnight["sun_energy"], 0.0)
	var midnight_light: float = midnight["ambient_energy"] + midnight["sun_energy"]
	assert_lt(midnight_light, noon["ambient_energy"] + noon["sun_energy"])
	var night_color: Color = midnight["ambient_color"]
	assert_gt(night_color.b, night_color.r, "la nuit est bleue")


func test_the_sun_rises_in_the_east_and_sets_in_the_west() -> void:
	var morning: Vector3 = DayLight.sample(8.0 * 60.0)["sun_direction"]
	var evening: Vector3 = DayLight.sample(18.0 * 60.0)["sun_direction"]
	var noon: Vector3 = DayLight.sample(13.0 * 60.0)["sun_direction"]
	assert_lt(morning.x, 0.0, "le matin, la lumière va vers l'ouest : elle vient de l'est")
	assert_gt(evening.x, 0.0)
	assert_lt(noon.y, morning.y, "à midi, le soleil tape plus d'aplomb")


func test_dawn_and_dusk_are_warm() -> void:
	var dusk: Color = DayLight.sample(19.75 * 60.0)["sun_color"]
	var noon: Color = DayLight.sample(12.0 * 60.0)["sun_color"]
	assert_gt(dusk.r - dusk.b, noon.r - noon.b)


func test_the_sky_of_a_zone_follows_the_clock() -> void:
	var zone := Zone.create("grigny2")
	add_child_autofree(zone)
	await wait_process_frames(2)
	var sky: ZoneSky = zone.get_node("Sky")
	var sun: DirectionalLight3D = sky.get_node("Sun")
	GameState.clock.minutes = 12.0 * 60.0
	sky.update_light()
	assert_true(sun.visible)
	var environment: Environment = sky.get_node("WorldEnvironment").environment
	var day_light := environment.ambient_light_energy + sun.light_energy
	GameState.clock.minutes = 0.0
	sky.update_light()
	assert_false(sun.visible, "pas de soleil la nuit")
	assert_lt(environment.ambient_light_energy, day_light)
	var night_color := environment.ambient_light_color
	assert_gt(night_color.b, night_color.r, "lumière de lune, bleutée")


func test_street_lamps_light_up_around_akan_at_night() -> void:
	var zone := Zone.create("grigny2@tour_akan")
	add_child_autofree(zone)
	await wait_process_frames(2)
	var lamps: LampLights = zone.get_node("LampLights")
	GameState.clock.minutes = 12.0 * 60.0
	lamps.update_lights()
	assert_eq(lamps.lit_count(), 0, "de jour, rien d'allumé")
	GameState.clock.minutes = 23.0 * 60.0
	lamps.update_lights()
	assert_eq(lamps.lit_count(), LampLights.POOL_SIZE)
	var nearest := INF
	for at: Vector3 in lamps.positions:
		nearest = minf(nearest, at.distance_to(zone.player.global_position))
	assert_gt(
		lamps.positions.size(), zone.geometry.lamp_positions.size(), "et les appliques des entrées"
	)
	assert_almost_eq(lamps.closest_light_distance(zone.player.global_position), nearest, 0.01)


func test_indoors_there_is_no_street_lamp() -> void:
	var home := Zone.create("appartement_akan")
	add_child_autofree(home)
	await wait_process_frames(2)
	assert_null(home.get_node_or_null("LampLights"))


func test_the_curfew_is_announced_then_enforced_then_lifted() -> void:
	watch_signals(EventBus)
	GameState.clock.minutes = 20 * 60.0 + 45.0
	GameState.advance_time(6.0 * 60.0 / GameClock.MINUTES_PER_SECOND / 60.0)
	assert_signal_emitted_with_parameters(EventBus, "notified", ["CURFEW_WARNING"])
	assert_false(GameState.is_curfew())
	GameState.advance_time(10.0)
	assert_true(GameState.is_curfew())
	assert_signal_emitted_with_parameters(EventBus, "curfew_changed", [true])
	assert_signal_emitted_with_parameters(EventBus, "notified", ["CURFEW_START"])
	GameState.clock.minutes = 5 * 60.0 + 59.0
	GameState.advance_time(2.0)
	assert_false(GameState.is_curfew())
	assert_signal_emitted_with_parameters(EventBus, "curfew_changed", [false])


func test_high_vigilance_brings_the_curfew_forward() -> void:
	GameState.territory_id = "grigny2"
	GameState.clock.minutes = 20 * 60.0 + 30.0
	assert_false(GameState.is_curfew())
	GameState.surveillance.report("grigny2", 3.0)
	assert_true(GameState.is_curfew(), "couvre-feu avancé d'une heure")
