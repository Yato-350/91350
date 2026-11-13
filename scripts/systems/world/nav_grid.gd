class_name NavGrid
extends RefCounted
## Chemins sur la grille de navigation d'une zone : A* (AStarGrid2D) sur des cases d'un
## mètre, en diagonale seulement si les deux cases voisines sont libres (on ne coupe pas
## l'angle d'un mur). Une cible hors d'atteinte donne le chemin vers le point le plus proche.

var _astar := AStarGrid2D.new()
var _nav: ZoneNavData


func _init(nav: ZoneNavData) -> void:
	_nav = nav
	_astar.region = Rect2i(Vector2i.ZERO, nav.size)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	# update() efface les cases pleines : on les pose après, par rangées entières.
	_astar.update()
	for y: int in nav.size.y:
		var run_start := -1
		for x: int in nav.size.x + 1:
			var solid := x < nav.size.x and nav.solid[y * nav.size.x + x] != 0
			if solid and run_start == -1:
				run_start = x
			elif not solid and run_start != -1:
				_astar.fill_solid_region(Rect2i(run_start, y, x - run_start, 1))
				run_start = -1


## Les centres des cases à suivre de `from` à `to` (vide si l'on est enfermé).
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := _nav.nearest_free_cell(_nav.cell_of(from))
	var goal := _nav.nearest_free_cell(_nav.cell_of(to))
	var points := PackedVector3Array()
	if start == ZoneNavData.NO_CELL or goal == ZoneNavData.NO_CELL:
		return points
	for cell: Vector2i in _astar.get_id_path(start, goal, true):
		points.append(_nav.center_of(cell))
	return points
