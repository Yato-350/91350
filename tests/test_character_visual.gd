extends GutTest

const PARTS: Array[String] = ["LegLeft", "LegRight", "Torso", "ArmLeft", "ArmRight", "Head"]


func test_model_has_six_articulated_parts() -> void:
	var visual := _make("akan")
	assert_true(visual.has_model())
	for part: String in PARTS:
		assert_not_null(visual.get_part(part), part)


func test_parts_use_the_palette_colours_of_the_vertices() -> void:
	var visual := _make("akan")
	var head := visual.get_part("Head") as MeshInstance3D
	var material := head.material_override as StandardMaterial3D
	assert_true(material.vertex_color_use_as_albedo)
	assert_true(material.vertex_color_is_srgb)


func test_walking_swings_legs_in_opposition() -> void:
	var visual := _make("akan")
	for i: int in 12:
		visual.animate(Vector3(2.5, 0.0, 0.0), 0.05)
	var left := visual.get_part("LegLeft").rotation.x
	var right := visual.get_part("LegRight").rotation.x
	assert_ne(left, 0.0)
	assert_almost_eq(left, -right, 0.001)
	assert_almost_eq(visual.get_part("ArmLeft").rotation.x, right, 0.001)


func test_standing_still_brings_limbs_back_to_rest() -> void:
	var visual := _make("akan")
	for i: int in 12:
		visual.animate(Vector3(2.5, 0.0, 0.0), 0.05)
	visual.animate(Vector3.ZERO, 0.05)
	assert_eq(visual.get_part("LegLeft").rotation.x, 0.0)


func test_walking_turns_the_model_towards_its_direction() -> void:
	var visual := _make("akan")
	for i: int in 60:
		visual.animate(Vector3(2.5, 0.0, 0.0), 0.05)
	# L'avant du modèle (-Z) pointe vers +X après un quart de tour.
	assert_almost_eq(-visual.global_basis.z, Vector3.RIGHT, Vector3.ONE * 0.01)


func test_unknown_character_shows_nothing_and_logs() -> void:
	var visual := _make("personne")
	assert_false(visual.has_model())
	assert_push_error("personne")


func test_every_character_of_the_roster_has_a_model() -> void:
	var data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/characters/characters.json")
	)
	for character: Dictionary in data["characters"]:
		var path := CharacterVisual.MODEL_PATH % character["id"]
		assert_true(ResourceLoader.exists(path), path)


func _make(character_id: String) -> CharacterVisual:
	var visual := CharacterVisual.new()
	visual.character_id = character_id
	add_child_autofree(visual)
	return visual
