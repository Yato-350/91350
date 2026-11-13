extends GutTest
## Chemins sur la grille d'un mètre : autour des murs, sans couper leurs angles.


func _grid() -> ZoneNavData:
	# 12 × 8 m ; un mur en x = 6, de y = 0 à y = 5 : il faut passer par le bas.
	var nav := ZoneNavData.create(Vector2(12.0, 8.0))
	for y: int in 6:
		nav.set_solid(Vector2i(6, y))
	return nav


func test_the_path_goes_round_the_wall() -> void:
	var nav := _grid()
	var grid := NavGrid.new(nav)
	var from := nav.center_of(Vector2i(2, 1))
	var to := nav.center_of(Vector2i(10, 1))
	var path := grid.path(from, to)
	assert_gt(path.size(), 8)
	assert_almost_eq(path[path.size() - 1], to, Vector3.ONE * 0.01)
	for point: Vector3 in path:
		assert_false(nav.is_solid_at(point), "jamais dans le mur : %s" % point)
	var below := false
	for point: Vector3 in path:
		below = below or nav.cell_of(point).y >= 6
	assert_true(below, "le chemin passe sous le mur")


func test_diagonals_never_cut_a_wall_corner() -> void:
	var nav := _grid()
	var path := NavGrid.new(nav).path(nav.center_of(Vector2i(5, 7)), nav.center_of(Vector2i(7, 4)))
	for index: int in range(1, path.size()):
		var a := nav.cell_of(path[index - 1])
		var b := nav.cell_of(path[index])
		if a.x != b.x and a.y != b.y:
			assert_false(nav.is_solid(Vector2i(a.x, b.y)) or nav.is_solid(Vector2i(b.x, a.y)))


func test_an_unreachable_goal_gives_the_closest_way() -> void:
	var nav := ZoneNavData.create(Vector2(12.0, 8.0))
	for y: int in 8:
		nav.set_solid(Vector2i(6, y))
	var grid := NavGrid.new(nav)
	var path := grid.path(nav.center_of(Vector2i(2, 4)), nav.center_of(Vector2i(10, 4)))
	assert_false(path.is_empty())
	assert_eq(nav.cell_of(path[path.size() - 1]).x, 5, "au pied du mur")


func test_a_start_inside_a_wall_starts_from_the_nearest_free_cell() -> void:
	var nav := _grid()
	var path := NavGrid.new(nav).path(nav.center_of(Vector2i(6, 1)), nav.center_of(Vector2i(2, 1)))
	assert_false(path.is_empty())
	assert_false(nav.is_solid_at(path[0]))
