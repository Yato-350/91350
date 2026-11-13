extends GutTest

var _zone: Zone


func before_each() -> void:
	GameState.new_game()
	_zone = Zone.create("grigny2")
	add_child_autofree(_zone)
	await wait_physics_frames(2)


func test_zone_loads_its_definition_and_geometry() -> void:
	assert_eq(_zone.zone_id, "grigny2")
	assert_not_null(_zone.geometry)
	assert_gt(_zone.geometry.zone_size.x, 300.0)
	assert_string_contains(_zone.geometry.attribution, "OpenStreetMap")
	assert_eq(_zone.definition["id"], "grigny2")


func test_player_spawns_on_free_ground_with_a_camera() -> void:
	assert_not_null(_zone.player)
	assert_false(_zone.geometry.nav_data.is_solid_at(_zone.player.global_position))
	await wait_physics_frames(30)
	assert_almost_eq(_zone.player.global_position.y, 0.0, 0.1)
	var camera := get_viewport().get_camera_3d()
	assert_not_null(camera)
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)


func test_nearest_free_moves_a_point_out_of_a_building() -> void:
	var nav := _zone.geometry.nav_data
	var inside := Vector3.INF
	for index: int in nav.solid.size():
		if nav.solid[index] != 0:
			inside = nav.center_of(Vector2i(index % nav.size.x, index / nav.size.x))
			break
	assert_true(nav.is_solid_at(inside))
	var free := _zone.nearest_free(inside)
	assert_false(nav.is_solid_at(free))
	assert_lt(free.distance_to(inside), 40.0)


func test_unknown_spawn_falls_back_to_the_default_one() -> void:
	assert_eq(_zone.spawn_position("inconnu"), _zone.spawn_position("default"))


func test_unknown_zone_is_refused() -> void:
	assert_null(Zone.create("atlantide"))
	assert_push_error("atlantide")


func test_markers_place_named_points_on_free_ground() -> void:
	var door := _zone.marker_position("tour_akan")
	assert_false(_zone.geometry.nav_data.is_solid_at(door))
	assert_lt(
		door.distance_to(Vector3(-142.2, 0.0, -153.1)), 1.5, "devant l'entrée réelle de la tour"
	)
	assert_eq(_zone.territory_id, "grigny2")
	assert_false(_zone.is_interior)


func test_an_interior_is_built_from_its_plan() -> void:
	var home := Zone.create("appartement_akan")
	add_child_autofree(home)
	await wait_physics_frames(30)
	assert_true(home.is_interior)
	assert_eq(home.territory_id, "grigny2")
	assert_gt(home.geometry.markers.size(), 1)
	assert_almost_eq(home.player.global_position.y, 0.0, 0.1)
	var at := home.player.global_position
	assert_almost_eq(Vector3(at.x, 0.0, at.z), home.marker_position("default"), Vector3.ONE * 0.1)


func test_a_named_marker_is_the_arrival_point() -> void:
	var home := Zone.create("appartement_akan@porte")
	add_child_autofree(home)
	await wait_physics_frames(2)
	var at := home.player.global_position
	assert_almost_eq(Vector3(at.x, 0.0, at.z), home.marker_position("porte"), Vector3.ONE * 0.1)


func test_doors_ask_to_travel_when_used() -> void:
	var home := Zone.create("appartement_akan@porte")
	add_child_autofree(home)
	await wait_physics_frames(3)
	watch_signals(EventBus)
	var door: Interactable = home.player.focus
	assert_not_null(door, "Akan arrive devant la porte")
	if door != null:
		door.interact(home.player)
	assert_signal_emitted_with_parameters(EventBus, "travel_requested", ["palier_11"])


func test_every_door_of_the_game_leads_somewhere() -> void:
	var places := DataRegistry.all("zones").duplicate()
	places.merge(DataRegistry.all("interiors"))
	for place_id: String in places:
		for door: Dictionary in places[place_id].get("doors", []):
			var target: String = door["to"]
			var place: Dictionary = places.get(target.get_slice("@", 0), {})
			assert_false(place.is_empty(), "%s → %s" % [place_id, target])
			var marker := target.get_slice("@", 1) if target.contains("@") else "default"
			var known: Array = place.get("markers", {}).values() + place.get("markers", {}).keys()
			assert_has(known, marker, "%s → %s" % [place_id, target])


func test_a_marker_can_be_written_in_metres() -> void:
	assert_eq(_zone.marker_position("12.5,-30"), _zone.nearest_free(Vector3(12.5, 0.0, -30.0)))
	assert_eq(_zone.marker_position("pas,un point"), _zone.marker_position())


func test_leaving_a_building_shows_its_facade() -> void:
	var outside := Zone.create("grigny2@tour_akan")
	add_child_autofree(outside)
	await wait_physics_frames(2)
	var rig: CameraRig = outside.find_children("*", "CameraRig", true, false)[0]
	assert_eq(rig.yaw_step, 2, "l'entrée de la tour regarde le nord-ouest")


func test_every_marker_is_reachable_on_foot_from_the_default_spawn() -> void:
	var nav := _zone.geometry.nav_data
	var reached := nav.reachable_from(nav.cell_of(_zone.marker_position()))
	for marker: String in _zone.markers:
		var cell := nav.cell_of(_zone.marker_position(marker))
		assert_eq(reached[cell.y * nav.size.x + cell.x], 1, "%s enfermé" % marker)


func test_most_building_entrances_are_reachable_on_foot() -> void:
	var nav := _zone.geometry.nav_data
	var reached := nav.reachable_from(nav.cell_of(_zone.marker_position()))
	var open := 0
	for entrance: Dictionary in _zone.geometry.entrances:
		var front: Vector3 = entrance["position"] + entrance["normal"] * 1.5
		var cell := nav.cell_of(_zone.nearest_free(front))
		open += reached[cell.y * nav.size.x + cell.x]
	assert_gte(open, _zone.geometry.entrances.size() * 0.9, "entrées accessibles : %d" % open)
