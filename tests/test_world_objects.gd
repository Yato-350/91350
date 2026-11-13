extends GutTest

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")


func before_each() -> void:
	GameState.new_game()


func test_a_voxel_model_is_loaded_by_its_id() -> void:
	var model := VoxelModel.instantiate("props/lit")
	add_child_autofree(model)
	var size := VoxelModel.bounds(model).size
	assert_almost_eq(size, Vector3(1.0, 0.5, 1.875), Vector3.ONE * 0.001)
	assert_null(VoxelModel.instantiate("props/licorne"))
	assert_push_error("props/licorne")


func test_a_solid_prop_blocks_the_way_with_a_box_of_its_size() -> void:
	var bed := Prop.create("lit", true)
	add_child_autofree(bed)
	var shape: CollisionShape3D = bed.find_children("*", "CollisionShape3D", true, false)[0]
	var box: BoxShape3D = shape.shape
	assert_almost_eq(box.size, Vector3(1.0, 0.5, 1.875), Vector3.ONE * 0.001)
	assert_almost_eq(shape.global_position.y, 0.25, 0.001)
	var rug := Prop.create("tapis", false)
	add_child_autofree(rug)
	assert_eq(rug.find_children("*", "CollisionShape3D", true, false).size(), 0)


func test_taking_a_pickup_fills_the_bag_and_is_remembered() -> void:
	var pickup := Pickup.create("bouteille_eau", 2, "essai:eau")
	add_child_autofree(pickup)
	assert_eq(pickup.prompt, "PROMPT_PRENDRE")
	pickup.interact(null)
	assert_eq(GameState.inventory.count("bouteille_eau"), 2)
	assert_true(GameState.has_flag(Pickup.TAKEN_FLAG % "essai:eau"))
	assert_true(pickup.is_queued_for_deletion())


func test_a_full_bag_leaves_the_pickup_on_the_ground() -> void:
	GameState.give("batte", 11)
	var pickup := Pickup.create("batte", 3, "essai:battes")
	add_child_autofree(pickup)
	watch_signals(EventBus)
	pickup.interact(null)
	assert_eq(GameState.inventory.count("batte"), 12)
	assert_eq(pickup.amount, 2, "il en reste deux par terre")
	assert_false(pickup.is_queued_for_deletion())
	assert_false(GameState.has_flag(Pickup.TAKEN_FLAG % "essai:battes"))
	pickup.interact(null)
	assert_signal_emitted_with_parameters(EventBus, "notified", ["HUD_BAG_FULL"])


func test_a_zone_places_its_props_and_pickups() -> void:
	var home := Zone.create("appartement_akan")
	add_child_autofree(home)
	await wait_physics_frames(2)
	assert_gt(home.find_children("*", "Prop", true, false).size(), 5)
	var pickups := home.find_children("*", "Pickup", true, false)
	assert_eq(pickups.size(), 1)
	var can: Pickup = pickups[0]
	assert_eq(can.item_id, "bidon_vide")
	can.interact(home.player)
	var again := Zone.create("appartement_akan")
	add_child_autofree(again)
	await wait_physics_frames(2)
	assert_eq(again.find_children("*", "Pickup", true, false).size(), 0, "déjà pris")


func test_dropped_items_land_at_the_feet_of_akan() -> void:
	var home := Zone.create("appartement_akan")
	add_child_autofree(home)
	await wait_physics_frames(2)
	GameState.give("batte", 14)
	await wait_process_frames(1)
	var dropped: Array[Node] = home.find_children("*", "Pickup", true, false).filter(
		func(node: Pickup) -> bool: return node.item_id == "batte"
	)
	assert_eq(dropped.size(), 1)
	var pile: Pickup = dropped[0]
	assert_eq(pile.amount, 2)
	assert_lt(pile.global_position.distance_to(home.player.global_position), 1.0)
