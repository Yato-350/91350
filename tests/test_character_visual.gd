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
		var path := VoxelModel.PATH % (CharacterVisual.MODEL_FOLDER + str(character["id"]))
		assert_true(ResourceLoader.exists(path), path)


func _make(character_id: String) -> CharacterVisual:
	var visual := CharacterVisual.new()
	visual.character_id = character_id
	add_child_autofree(visual)
	return visual


func test_crouching_lowers_the_body_and_keeps_the_feet_on_the_ground() -> void:
	var visual := CharacterVisual.new()
	visual.character_id = "akan"
	add_child_autofree(visual)
	var head := visual.get_part("Head")
	var leg := visual.get_part("LegLeft")
	var hip := leg.position.y
	var standing_head := head.position.y
	visual.crouched = true
	for i: int in 30:
		visual.animate(Vector3.ZERO, 1.0 / 60.0)
	assert_almost_eq(visual.get_crouch_drop(), CharacterVisual.CROUCH_DROP, 0.001)
	assert_almost_eq(head.position.y, standing_head - CharacterVisual.CROUCH_DROP, 0.001)
	assert_almost_eq(leg.position.y * 1.0 / leg.scale.y, hip, 0.001, "les pieds restent au sol")
	visual.crouched = false
	for i: int in 30:
		visual.animate(Vector3.ZERO, 1.0 / 60.0)
	# Debout et immobile, il respire : la tête peut être un voxel plus haut.
	var breath := head.position.y - standing_head
	assert_true(
		is_zero_approx(breath) or is_equal_approx(breath, CharacterVisual.BREATH_STEP),
		"debout : %f" % breath
	)
	assert_almost_eq(leg.scale.y, 1.0, 0.001)


func test_an_idle_body_breathes_by_one_voxel() -> void:
	var visual := _make("akan")
	var torso := visual.get_part("Torso")
	var heights := {}
	for i: int in 60:
		visual.update_pose(CharacterVisual.BREATH_PERIOD / 30.0)
		heights[snappedf(torso.position.y, 0.001)] = true
	assert_eq(heights.size(), 2, "deux hauteurs : inspiré, expiré")
	var values: Array = heights.keys()
	assert_almost_eq(absf(values[0] - values[1]), CharacterVisual.BREATH_STEP, 0.002)


func test_running_leans_forward_and_walking_does_not() -> void:
	var runner := _make("akan")
	for i: int in 20:
		runner.animate(Vector3(5.5, 0.0, 0.0), 0.05)
	assert_lt(runner.rotation.x, -0.1, "penché en avant")
	var walker := _make("akan")
	for i: int in 20:
		walker.animate(Vector3(2.5, 0.0, 0.0), 0.05)
	assert_almost_eq(walker.rotation.x, 0.0, 0.01)


func test_the_head_turns_towards_a_point_but_not_all_the_way_round() -> void:
	var visual := _make("akan")
	visual.look_at_point(visual.global_position + Vector3(3.0, 1.5, 0.0))
	for i: int in 30:
		visual.update_pose(0.05)
	var head := visual.get_part("Head")
	assert_lt(head.rotation.y, -0.5, "la tête tourne vers la droite (+X)")
	visual.look_at_point(visual.global_position + Vector3(0.0, 1.5, 3.0))
	for i: int in 30:
		visual.update_pose(0.05)
	assert_lte(absf(head.rotation.y), CharacterVisual.HEAD_TURN_LIMIT + 0.001)
	visual.stop_looking()
	for i: int in 60:
		visual.update_pose(0.05)
	assert_almost_eq(head.rotation.y, 0.0, 0.01)


func test_carrying_holds_both_arms_forward_even_while_walking() -> void:
	var visual := _make("akan")
	visual.carrying = true
	for i: int in 12:
		visual.animate(Vector3(2.5, 0.0, 0.0), 0.05)
		visual.update_pose(0.05)
	assert_almost_eq(visual.get_part("ArmLeft").rotation.x, CharacterVisual.CARRY_ANGLE, 0.001)
	assert_almost_eq(visual.get_part("ArmRight").rotation.x, CharacterVisual.CARRY_ANGLE, 0.001)


func test_talking_moves_the_right_arm() -> void:
	var visual := _make("akan")
	visual.talking = true
	var angles := {}
	for i: int in 20:
		visual.update_pose(0.05)
		angles[snappedf(visual.get_part("ArmRight").rotation.x, 0.01)] = true
		assert_lt(visual.get_part("ArmRight").rotation.x, 0.0, "le bras reste levé")
	assert_gt(angles.size(), 3, "il bouge en parlant")
