extends GutTest

const HEIGHT := 8.4
const ZONE := {
	"zone": "essai",
	"size": [80.0, 60.0],
	"attribution": "© les contributeurs d'OpenStreetMap — données sous licence ODbL",
	"buildings":
	[
		{
			"id": 1,
			"kind": "residential",
			"neutral": false,
			"levels": 3,
			"height": HEIGHT,
			"points": [[-5.0, -5.0], [-5.0, 5.0], [5.0, 5.0], [5.0, -5.0]],
		},
	],
	"roads":
	[
		{
			"id": 2,
			"kind": "residential",
			"width": 6.0,
			"name": "",
			"points": [[-40.0, 20.0], [40.0, 20.0]]
		},
	],
	"rails": [],
	"water":
	[
		{
			"id": 3,
			"kind": "water",
			"name": "",
			"points": [[20.0, -25.0], [20.0, -15.0], [30.0, -15.0]]
		}
	],
	"green":
	[
		{
			"id": 4,
			"kind": "park",
			"name": "",
			"points": [[-30.0, -25.0], [-30.0, -15.0], [-20.0, -15.0]]
		}
	],
	"pois": [],
}

var _geometry: ZoneGeometry


func before_each() -> void:
	_geometry = ZoneGeometryBuilder.build(ZONE, Palette.load_colors())
	add_child_autofree(_geometry)
	await wait_physics_frames(2)


func test_layers_are_built() -> void:
	for layer: String in ["Ground", "Green", "Water", "Roads", "Buildings", "Bounds"]:
		assert_not_null(_geometry.get_node_or_null(layer), layer)
	assert_eq(_geometry.zone_size, Vector2(80.0, 60.0))
	assert_string_contains(_geometry.attribution, "OpenStreetMap")


func test_building_is_extruded_to_its_height() -> void:
	var chunk: MeshInstance3D = _geometry.get_node("Buildings").get_child(0)
	var bounds := chunk.mesh.get_aabb()
	assert_almost_eq(bounds.size, Vector3(10.0, HEIGHT, 10.0), Vector3.ONE * 0.01)
	assert_almost_eq(bounds.position.y, 0.0, 0.01)
	# 4 murs et un toit, deux triangles chacun.
	assert_eq(chunk.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size(), 10 * 3)


func test_walls_stop_a_ray_from_outside_only() -> void:
	var outside := Vector3(20.0, 2.0, 0.0)
	var inside := Vector3(0.0, 2.0, 0.0)
	var hit := _ray(outside, inside)
	assert_false(hit.is_empty(), "un mur doit arrêter un rayon venu de dehors")
	assert_almost_eq(hit["position"].x, 5.0, 0.01)
	assert_almost_eq(hit["normal"], Vector3(1.0, 0.0, 0.0), Vector3.ONE * 0.01)
	assert_true(_ray(inside, outside).is_empty(), "les faces arrière ne comptent pas")


func test_ground_and_roof_carry_weight() -> void:
	var on_ground := _ray(Vector3(-20.0, 5.0, 0.0), Vector3(-20.0, -5.0, 0.0))
	assert_almost_eq(on_ground["position"].y, 0.0, 0.01)
	var on_roof := _ray(Vector3(0.0, 20.0, 0.0), Vector3(0.0, -5.0, 0.0))
	assert_almost_eq(on_roof["position"].y, HEIGHT, 0.01)


func test_bounds_close_the_zone() -> void:
	var hit := _ray(Vector3(0.0, 1.0, 25.0), Vector3(0.0, 1.0, 40.0))
	assert_false(hit.is_empty())
	assert_almost_eq(hit["position"].z, 30.0, 0.01)


func test_navigation_grid_blocks_buildings_and_water() -> void:
	var nav := _geometry.nav_data
	assert_eq(nav.size, Vector2i(80, 60))
	assert_true(nav.is_solid_at(Vector3(0.0, 0.0, 0.0)), "intérieur du bâtiment")
	assert_true(nav.is_solid_at(Vector3(22.0, 0.0, -17.0)), "eau")
	assert_false(nav.is_solid_at(Vector3(0.0, 0.0, 20.0)), "route")
	assert_false(nav.is_solid_at(Vector3(-26.0, 0.0, -18.0)), "parc")
	assert_true(nav.is_solid_at(Vector3(200.0, 0.0, 0.0)), "hors de la zone")


func test_geometry_survives_packing_into_a_scene() -> void:
	var scene := PackedScene.new()
	assert_eq(scene.pack(_geometry), OK)
	var copy: ZoneGeometry = scene.instantiate()
	add_child_autofree(copy)
	assert_eq(copy.nav_data.size, Vector2i(80, 60))
	assert_not_null(copy.get_node("Buildings").get_child(0))


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	return _geometry.get_world_3d().direct_space_state.intersect_ray(query)
