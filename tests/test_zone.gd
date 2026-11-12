extends GutTest

var _zone: Zone


func before_each() -> void:
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
