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

const FURNISHED := {
	"id": "meuble",
	"plan":
	[
		"#######",
		"#a.tt.#",
		"#c...c#",
		"#######",
	],
	"markers": {"a": "default"},
	"props": {"t": {"model": "table"}, "c": {"model": "chaise", "yaw": 90, "solid": false}},
}

## Deux pièces : à gauche le sol par défaut, à droite une salle d'eau carrelée, aux murs
## bleus ; entre les deux, une gaine en bois ; une baignoire dans le coin de la salle d'eau ;
## une fenêtre à l'ouest.
const ROOMS := {
	"id": "pieces",
	"plan":
	[
		"########",
		"#a.#~uu#",
		"F..P~uu#",
		"#..#~~~D",
		"########",
	],
	"markers": {"a": "default"},
	"floors": {"~": "beton_5"},
	"wall_colors": {"~": "bleu_ecran"},
	"props": {"u": {"model": "table"}},
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


func test_neighbouring_cells_of_a_prop_make_one_piece_of_furniture() -> void:
	var placements := InteriorBuilder.prop_placements(FURNISHED)
	assert_eq(placements.size(), 3)
	assert_eq(placements[0]["model"], "table")
	assert_eq(placements[0]["position"], Vector3(0.5, 0.0, -0.5))
	assert_eq(placements[0]["yaw"], 0.0)
	assert_true(placements[0]["solid"])
	assert_eq(placements[1]["model"], "chaise")
	assert_eq(placements[1]["position"], Vector3(-2.0, 0.0, 0.5))
	assert_eq(placements[1]["yaw"], 90.0)
	assert_false(placements[1]["solid"])
	assert_eq(placements[2]["position"], Vector3(2.0, 0.0, 0.5))


func test_furniture_against_a_wall_knows_how_far_the_wall_is() -> void:
	var room := {
		"id": "chambre",
		"plan": ["######", "#a.bb#", "#....#", "#..r.#", "######"],
		"markers": {"a": "default"},
		"props":
		{
			"b": {"model": "lit", "yaw": 180, "against_wall": true},
			"r": {"model": "armoire", "yaw": -90, "against_wall": true},
		},
	}
	var placements := InteriorBuilder.prop_placements(room)
	var bed := placements[0]
	assert_eq(bed["back"], Vector3(0.0, 0.0, -1.0), "à 180°, le dos regarde le nord")
	var face := 1.0 - InteriorBuilder.WALL_THICKNESS / 2.0
	assert_almost_eq(bed["back_gap"], face, 0.001, "du milieu du lit à la face du mur")
	var wardrobe := placements[1]
	assert_eq(wardrobe["back"], Vector3(-1.0, 0.0, 0.0), "à -90°, le dos regarde l'ouest")
	assert_almost_eq(wardrobe["back_gap"], 2.0 + face, 0.001, "le mur est deux cases plus loin")
	assert_false(InteriorBuilder.prop_placements(FURNISHED)[0].has("back_gap"), "sinon, rien")


func test_solid_furniture_blocks_the_navigation_grid() -> void:
	var furnished := InteriorBuilder.build(FURNISHED, _palette)
	add_child_autofree(furnished)
	assert_true(furnished.nav_data.is_solid(Vector2i(3, 1)), "la table")
	assert_true(furnished.nav_data.is_solid(Vector2i(4, 1)), "la table")
	assert_false(furnished.nav_data.is_solid(Vector2i(1, 2)), "une chaise se contourne")
	assert_eq(InteriorBuilder.plan_errors(FURNISHED), [] as Array[String])


func test_each_side_of_a_wall_takes_the_colour_of_the_room_it_faces() -> void:
	var between := Vector2i(3, 1)
	assert_eq(InteriorBuilder.side_color_id(ROOMS, between, Vector2i.LEFT), "creme")
	assert_eq(InteriorBuilder.side_color_id(ROOMS, between, Vector2i.RIGHT), "bleu_ecran")
	assert_eq(
		InteriorBuilder.side_color_id(ROOMS, Vector2i(5, 0), Vector2i.UP), "beton_1", "le dehors"
	)
	assert_eq(
		InteriorBuilder.side_color_id(ROOMS, Vector2i(3, 2), Vector2i.LEFT), "peau_1", "la gaine"
	)
	assert_eq(
		InteriorBuilder.side_color_id(ROOMS, Vector2i(0, 2), Vector2i.RIGHT),
		"bleu_ciel",
		"une fenêtre"
	)
	assert_eq(
		InteriorBuilder.side_color_id(ROOMS, Vector2i(7, 3), Vector2i.LEFT),
		"brun_1",
		"une porte reste une porte"
	)


func test_a_wall_behind_furniture_still_belongs_to_the_room() -> void:
	# La baignoire couvre le coin : sa pièce se cherche au-delà de ses cases.
	assert_eq(InteriorBuilder.side_color_id(ROOMS, Vector2i(7, 1), Vector2i.LEFT), "bleu_ecran")
	assert_eq(
		InteriorBuilder.floor_color_id(ROOMS, Vector2i(6, 1)),
		"beton_5",
		"pas de parquet sous la baignoire"
	)
	assert_eq(InteriorBuilder.floor_color_id(ROOMS, Vector2i(1, 1)), "brun_2", "le sol par défaut")


func test_the_walls_are_painted_room_by_room() -> void:
	var rooms := InteriorBuilder.build(ROOMS, _palette)
	add_child_autofree(rooms)
	var colors := _mesh_colors(rooms.get_node("Walls"))
	for color_id: String in ["bleu_ecran", "creme", "peau_1", "brun_1"]:
		assert_true(colors.has(_palette[color_id]), color_id)
	assert_eq(InteriorBuilder.plan_errors(ROOMS), [] as Array[String])


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
		"inconnu": {"plan": ["####", "#az#", "####"], "markers": {"a": "default"}},
		"licorne":
		{
			"plan": ["####", "#at#", "####"],
			"markers": {"a": "default"},
			"props": {"t": {"model": "licorne"}},
		},
		"fuchsia":
		{"plan": ["####", "#a.#", "####"], "markers": {"a": "default"}, "wall_color": "fuchsia"},
		"sol absent":
		{
			"plan": ["####", "#a.#", "####"],
			"markers": {"a": "default"},
			"wall_colors": {"~": "blanc"},
		},
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


# Les couleurs des sommets d'un maillage.
func _mesh_colors(mesh_instance: MeshInstance3D) -> Dictionary:
	var colors := {}
	for color: Color in mesh_instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		colors[color] = true
	return colors
