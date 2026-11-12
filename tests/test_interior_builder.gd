extends GutTest

const DEFINITION := {
	"id": "essai",
	"plan":
	[
		"######",
		"#a.,#D",
		"#..,b#",
		"######",
	],
	"markers": {"a": "default", "b": "porte"},
	"floors": {",": "beton_5"},
}

var _palette: Dictionary
var _geometry: ZoneGeometry


func before_each() -> void:
	_palette = Palette.load_colors()
	_geometry = InteriorBuilder.build(DEFINITION, _palette)
	add_child_autofree(_geometry)


func test_the_plan_gives_the_size_and_the_navigation_grid() -> void:
	assert_eq(_geometry.zone_id, "essai")
	assert_eq(_geometry.zone_size, Vector2(6.0, 4.0))
	var nav := _geometry.nav_data
	assert_eq(nav.size, Vector2i(6, 4))
	assert_true(nav.is_solid(Vector2i(0, 0)), "mur")
	assert_true(nav.is_solid(Vector2i(5, 1)), "porte fermée")
	assert_false(nav.is_solid(Vector2i(1, 1)), "repère : du sol")
	assert_false(nav.is_solid(Vector2i(3, 2)), "sol carrelé")


func test_letters_become_named_markers_at_the_cell_center() -> void:
	assert_eq(_geometry.markers.keys(), ["default", "porte"])
	assert_eq(_geometry.markers["default"], Vector3(-1.5, 0.0, -0.5))
	assert_eq(_geometry.markers["porte"], Vector3(1.5, 0.0, 0.5))


func test_floor_and_walls_are_drawn_and_solid() -> void:
	var floor_mesh: MeshInstance3D = _geometry.get_node("Floor")
	var walls: MeshInstance3D = _geometry.get_node("Walls")
	assert_not_null(floor_mesh.mesh)
	assert_not_null(walls.mesh)
	var thickness := InteriorBuilder.WALL_THICKNESS
	assert_almost_eq(
		walls.get_aabb().size,
		Vector3(5.0 + thickness, InteriorBuilder.WALL_HEIGHT, 3.0 + thickness),
		Vector3.ONE * 0.001,
		"des murs fins, au milieu de leur case"
	)
	assert_almost_eq(
		floor_mesh.get_aabb().size,
		Vector3(5.0, 0.0, 3.0),
		Vector3.ONE * 0.001,
		"le sol va jusque sous les murs, pas au-delà"
	)
	var shapes := _geometry.find_children("*", "CollisionShape3D", true, false)
	assert_between(shapes.size(), 2, 8)
	await wait_physics_frames(2)
	var space := _geometry.get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(
		Vector3(-1.5, 2.0, -0.5), Vector3(-1.5, -2.0, -0.5)
	)
	assert_almost_eq(space.intersect_ray(down)["position"].y, 0.0, 0.001, "le sol porte")
	var across := PhysicsRayQueryParameters3D.create(
		Vector3(-1.5, 1.5, -0.5), Vector3(-5.0, 1.5, -0.5)
	)
	assert_false(space.intersect_ray(across).is_empty(), "le mur arrête, plus haut que son dessin")


func test_a_sound_plan_has_no_error() -> void:
	assert_eq(InteriorBuilder.plan_errors(DEFINITION), [] as Array[String])


func test_plan_errors_name_each_defect() -> void:
	var cases := {
		"plan": {"id": "x"},
		"largeur": {"plan": ["####", "#a#", "####"], "markers": {"a": "default"}},
		"vide": {"plan": ["####", "#a. ", "####"], "markers": {"a": "default"}},
		"bord": {"plan": ["#.##", "#a.#", "####"], "markers": {"a": "default"}},
		"deux fois": {"plan": ["#####", "#aa.#", "#####"], "markers": {"a": "default"}},
		"absent": {"plan": ["####", "#a.#", "####"], "markers": {"a": "default", "z": "lit"}},
		"default": {"plan": ["####", "#a.#", "####"], "markers": {"a": "lit"}},
	}
	for expected: String in cases:
		var errors := InteriorBuilder.plan_errors(cases[expected])
		assert_eq(errors.size(), 1, expected)
		if errors.size() == 1:
			assert_string_contains(errors[0], expected)


func test_every_interior_of_the_game_has_a_sound_plan() -> void:
	var interiors := DataRegistry.all("interiors")
	assert_gt(interiors.size(), 0)
	for interior_id: String in interiors:
		assert_eq(
			InteriorBuilder.plan_errors(interiors[interior_id]), [] as Array[String], interior_id
		)
