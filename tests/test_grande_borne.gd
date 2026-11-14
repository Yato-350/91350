extends GutTest
## La Grande Borne (acte 2) : la zone se charge depuis ses données OpenStreetMap, ses repères
## sont accessibles à pied, et la passerelle de l'A6 la relie à Grigny 2 dans les deux sens.

var _zone: Zone


func before_all() -> void:
	GameState.new_game()
	_zone = Zone.create("grande_borne")
	add_child(_zone)
	await wait_physics_frames(2)


func after_all() -> void:
	_zone.free()


func test_the_zone_comes_from_openstreetmap() -> void:
	assert_eq(_zone.zone_id, "grande_borne")
	assert_eq(_zone.territory_id, "grande_borne")
	assert_string_contains(_zone.geometry.attribution, "OpenStreetMap")
	assert_gt(_zone.geometry.zone_size.x, 600.0)


func test_every_marker_is_reachable_on_foot_from_the_default_spawn() -> void:
	var nav := _zone.geometry.nav_data
	var reached := nav.reachable_from(nav.cell_of(_zone.marker_position()))
	for marker: String in _zone.markers:
		var cell := nav.cell_of(_zone.marker_position(marker))
		assert_eq(reached[cell.y * nav.size.x + cell.x], 1, "%s enfermé" % marker)


func test_the_footbridge_links_both_sides_of_the_a6() -> void:
	var exits := PlaceGraph.exits()
	assert_has(exits.get("grande_borne", []), "grigny2")
	assert_has(exits.get("grigny2", []), "grande_borne")


func test_the_footbridge_opens_once_grigny2_is_free() -> void:
	var door: Dictionary = {}
	for candidate: Dictionary in DataRegistry.entry("zones", "grigny2").get("doors", []):
		if String(candidate["to"]).begins_with("grande_borne"):
			door = candidate
	assert_false(door.is_empty())
	assert_false(Conditions.check(door.get("if", {})), "fermée pendant l'acte 1")
	GameState.territory.liberate("grigny2")
	assert_true(Conditions.check(door.get("if", {})), "ouverte une fois Grigny 2 libérée")
	GameState.new_game()
