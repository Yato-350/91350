extends GutTest
## Perception : ce qui cache la vue, le cône de vision, la jauge d'attention.


func _grid_with_wall() -> ZoneNavData:
	# 10 × 5 m ; un mur opaque en x = 5 sur toute la hauteur, sauf la dernière rangée.
	var nav := ZoneNavData.create(Vector2(10.0, 5.0))
	for y: int in 4:
		nav.set_solid(Vector2i(5, y))
		nav.set_opaque(Vector2i(5, y))
	return nav


func test_a_wall_blocks_the_line_of_sight_but_an_opening_does_not() -> void:
	var nav := _grid_with_wall()
	var left := nav.center_of(Vector2i(1, 1))
	var right := nav.center_of(Vector2i(8, 1))
	assert_false(nav.line_of_sight(left, right))
	assert_true(nav.line_of_sight(nav.center_of(Vector2i(1, 4)), nav.center_of(Vector2i(8, 4))))
	assert_true(nav.line_of_sight(left, nav.center_of(Vector2i(4, 3))), "du même côté")


func test_what_blocks_the_way_does_not_always_block_the_view() -> void:
	var nav := ZoneNavData.create(Vector2(10.0, 5.0))
	nav.set_solid(Vector2i(5, 1))
	assert_true(nav.line_of_sight(nav.center_of(Vector2i(1, 1)), nav.center_of(Vector2i(8, 1))))
	assert_false(nav.is_opaque(Vector2i(5, 1)), "une voiture, un tronc, une grille")
	assert_true(nav.is_opaque(Vector2i(-1, 0)), "hors de la zone : rien ne se voit")


func test_buildings_and_hedges_are_opaque_but_fences_are_not() -> void:
	var zone := {
		"zone": "essai",
		"size": [40.0, 30.0],
		"buildings":
		[
			{
				"id": 1,
				"kind": "residential",
				"neutral": false,
				"levels": 3,
				"height": 8.4,
				"points": [[-5.0, -5.0], [5.0, -5.0], [5.0, 5.0], [-5.0, 5.0]],
			}
		],
		"barriers":
		[
			{"id": 2, "kind": "fence", "points": [[-15.0, 10.0], [-8.0, 10.0]]},
			{"id": 3, "kind": "hedge", "points": [[8.0, 10.0], [15.0, 10.0]]},
		],
	}
	var geometry := ZoneGeometryBuilder.build(zone, Palette.load_colors())
	add_child_autofree(geometry)
	var nav := geometry.nav_data
	assert_true(nav.is_opaque(nav.cell_of(Vector3(0.0, 0.0, 0.0))), "immeuble")
	assert_true(nav.is_opaque(nav.cell_of(Vector3(4.5, 0.0, 0.0))), "juste à l'intérieur")
	assert_false(nav.is_opaque(nav.cell_of(Vector3(5.5, 0.0, 0.0))), "juste dehors")
	assert_false(nav.is_opaque(nav.cell_of(Vector3(-12.0, 0.0, 10.0))), "grille")
	assert_true(nav.is_opaque(nav.cell_of(Vector3(12.0, 0.0, 10.0))), "haie")


func test_interior_walls_are_opaque() -> void:
	var geometry := InteriorBuilder.build(
		{"id": "essai", "plan": ["#####", "#a#.#", "#####"], "markers": {"a": "default"}},
		Palette.load_colors()
	)
	add_child_autofree(geometry)
	assert_true(geometry.nav_data.is_opaque(Vector2i(2, 1)))
	assert_false(geometry.nav_data.is_opaque(Vector2i(1, 1)))


func test_the_view_cone_has_a_range_an_angle_and_respects_walls() -> void:
	var nav := _grid_with_wall()
	var eye := nav.center_of(Vector2i(1, 1))
	var east := -PI / 2.0
	assert_true(Vision.can_see(eye, east, deg_to_rad(30.0), 6.0, eye + Vector3(3.0, 0, 0), nav))
	assert_false(
		Vision.can_see(eye, east, deg_to_rad(30.0), 2.0, eye + Vector3(3.0, 0, 0), nav), "trop loin"
	)
	assert_false(
		Vision.can_see(eye, east, deg_to_rad(30.0), 6.0, eye + Vector3(0, 0, 3.0), nav),
		"hors du cône"
	)
	assert_false(
		Vision.can_see(eye, east, deg_to_rad(30.0), 9.0, eye + Vector3(7.0, 0, 0), nav), "mur"
	)
	assert_true(Vision.can_see(eye, east, deg_to_rad(30.0), 6.0, eye, nav), "sur place")


func test_attention_grows_faster_up_close_and_slower_when_crouched() -> void:
	var near := Awareness.new()
	var far := Awareness.new()
	var crouched := Awareness.new()
	near.update(0.2, true, 1.0, 10.0, false)
	far.update(0.2, true, 9.0, 10.0, false)
	crouched.update(0.2, true, 1.0, 10.0, true)
	assert_gt(near.value, far.value)
	assert_gt(near.value, crouched.value)
	assert_false(near.is_alerted())
	for i: int in 20:
		near.update(0.2, true, 1.0, 10.0, false)
	assert_true(near.is_alerted())
	assert_eq(near.value, 1.0)


func test_attention_fades_when_the_target_is_out_of_sight() -> void:
	var awareness := Awareness.new()
	awareness.update(0.5, true, 2.0, 10.0, false)
	var seen := awareness.value
	awareness.update(0.5, false, 2.0, 10.0, false)
	assert_lt(awareness.value, seen)
	for i: int in 30:
		awareness.update(0.5, false, 2.0, 10.0, false)
	assert_eq(awareness.value, 0.0)
