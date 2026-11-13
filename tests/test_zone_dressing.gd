extends GutTest
## Habillage d'une petite zone d'essai : un immeuble, une rue, un parking, un parc.

const ROAD_Z := 20.0
const ZONE := {
	"zone": "essai",
	"size": [100.0, 80.0],
	"attribution": "© les contributeurs d'OpenStreetMap — données sous licence ODbL",
	"buildings":
	[
		{
			"id": 1,
			"kind": "residential",
			"neutral": false,
			"levels": 3,
			"height": 8.4,
			"points": [[-5.0, -5.0], [5.0, -5.0], [5.0, 5.0], [-5.0, 5.0]],
		},
	],
	"roads":
	[
		{
			"id": 2,
			"kind": "residential",
			"width": 6.5,
			"name": "",
			"points": [[-50.0, ROAD_Z], [50.0, ROAD_Z]],
		},
	],
	"rails": [],
	"water": [],
	"green":
	[
		{
			"id": 3,
			"kind": "park",
			"name": "",
			"points": [[-48.0, -38.0], [-20.0, -38.0], [-20.0, -10.0], [-48.0, -10.0]],
		},
	],
	"pois": [],
	"trees": [[-30.0, 10.0]],
	"entrances": [{"x": 0.0, "z": 5.0, "kind": "staircase", "building": 1, "normal": [0.0, 1.0]}],
	"parkings":
	[
		{
			"id": 4,
			"kind": "surface",
			"name": "",
			"points": [[10.0, -30.0], [40.0, -30.0], [40.0, -5.0], [10.0, -5.0]],
		},
	],
	"barriers": [{"id": 5, "kind": "fence", "points": [[-15.0, 10.0], [-5.0, 10.0]]}],
	"gates": [[-10.0, 10.0]],
	"crossings": [{"x": 0.0, "z": ROAD_Z, "angle": 0.0}],
	"furniture":
	[
		{"kind": "banc", "x": -20.0, "z": 25.0, "angle": 0.0},
		{"kind": "pylone", "x": 40.0, "z": 30.0, "angle": 0.0},
	],
	"power_lines": [],
}

var _geometry: ZoneGeometry


func before_each() -> void:
	_geometry = ZoneGeometryBuilder.build(ZONE, Palette.load_colors())
	add_child_autofree(_geometry)
	await wait_physics_frames(2)


func test_sidewalks_and_markings_are_drawn() -> void:
	for layer: String in ["Sidewalks", "Markings", "Parkings"]:
		var node: MeshInstance3D = _geometry.find_child(layer, true, false)
		assert_not_null(node, layer)
		if node != null:
			assert_not_null(node.mesh, layer)


func test_trees_come_from_the_map_and_from_the_park_but_never_on_a_road_or_a_building() -> void:
	var trees := _positions(["arbre_feuillu", "arbre_haut", "pin"])
	assert_gt(trees.size(), 3, "l'arbre de la carte et ceux du parc")
	assert_true(
		trees.any(func(at: Vector3) -> bool: return at.distance_to(Vector3(-30, 0, 10)) < 0.1)
	)
	for at: Vector3 in trees:
		assert_gt(
			absf(at.z - ROAD_Z), 3.25 + ZoneDressing.TREE_ROAD_MARGIN - 0.01, "pas sur la rue"
		)
		assert_false(absf(at.x) < 5.0 and absf(at.z) < 5.0, "pas dans l'immeuble")


func test_the_parking_gets_parked_cars_inside_it() -> void:
	var cars := _positions(ZoneDressing.CAR_MODELS)
	assert_gt(cars.size(), 3)
	for at: Vector3 in cars:
		assert_between(at.x, 10.0, 40.0)
		assert_between(at.z, -30.0, -5.0)


func test_lamps_line_the_street_and_are_listed_for_the_night() -> void:
	assert_gt(_geometry.lamp_positions.size(), 1)
	for at: Vector3 in _geometry.lamp_positions:
		assert_between(absf(at.z - ROAD_Z), 3.0, 6.0, "sur le trottoir")
		assert_gt(at.y, 4.0, "la lanterne est en haut du mât")


func test_entrances_get_a_door_against_their_wall() -> void:
	assert_eq(_geometry.entrances.size(), 1)
	var entrance: Dictionary = _geometry.entrances[0]
	assert_almost_eq(entrance["position"], Vector3(0.0, 0.0, 5.0), Vector3.ONE * 0.01)
	assert_almost_eq(entrance["normal"], Vector3(0.0, 0.0, 1.0), Vector3.ONE * 0.01)
	var doors := _positions(["entree_immeuble"])
	assert_eq(doors.size(), 1)
	assert_between(doors[0].z, 5.0, 5.6, "devant le mur, pas dedans")


func test_fences_block_the_way_except_at_their_gates() -> void:
	var nav := _geometry.nav_data
	assert_true(nav.is_solid_at(Vector3(-13.5, 0.0, 10.0)), "la clôture")
	assert_false(nav.is_solid_at(Vector3(-10.0, 0.0, 10.0)), "le portail")
	assert_false(_ray(Vector3(-13.5, 0.6, 12.0), Vector3(-13.5, 0.6, 8.0)).is_empty())
	assert_true(_ray(Vector3(-10.0, 0.6, 12.0), Vector3(-10.0, 0.6, 8.0)).is_empty())


func test_obstacles_have_collisions_and_block_their_cells() -> void:
	var trunk := Vector3(-30.0, 1.0, 10.0)
	assert_false(_ray(trunk + Vector3(-2.0, 0.0, 0.0), trunk).is_empty(), "un tronc arrête")
	assert_true(_geometry.nav_data.is_solid_at(trunk))
	var bench := Vector3(-20.0, 0.3, 25.0)
	assert_false(_ray(bench + Vector3(0.0, 0.0, 2.0), bench).is_empty(), "un banc arrête")


func test_dressing_survives_packing_into_a_scene() -> void:
	var scene := PackedScene.new()
	assert_eq(scene.pack(_geometry), OK)
	var copy: ZoneGeometry = scene.instantiate()
	add_child_autofree(copy)
	assert_eq(copy.lamp_positions.size(), _geometry.lamp_positions.size())
	assert_eq(copy.entrances.size(), 1)
	var count := 0
	for node: Node in copy.find_children("*", "PropInstances", true, false):
		var instances := node as PropInstances
		assert_not_null(instances.multimesh.mesh, "le maillage est enregistré avec la scène")
		assert_eq(instances.multimesh.instance_count, instances.transforms.size())
		count += instances.transforms.size()
	assert_gt(count, 10)


# Positions des instances des modèles donnés (tous carrés confondus).
func _positions(models: Array) -> Array[Vector3]:
	var found: Array[Vector3] = []
	for node: Node in _geometry.find_children("*", "PropInstances", true, false):
		var instances := node as PropInstances
		if not instances.model in models:
			continue
		for transform: Transform3D in instances.transforms:
			var at := Vector3(transform.origin.x, 0.0, transform.origin.z)
			if not found.any(func(other: Vector3) -> bool: return other.is_equal_approx(at)):
				found.append(at)
	return found


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return _geometry.get_world_3d().direct_space_state.intersect_ray(query)
