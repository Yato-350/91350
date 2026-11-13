extends GutTest
## Le repère de quête : au-dessus de la cible si elle est ici, sinon au-dessus de la porte
## qui y mène ; caché quand l'objectif n'a pas de lieu.


func before_each() -> void:
	GameState.new_game()
	GameState.quests.start(GameState.FIRST_QUEST)


func test_the_next_place_on_the_way_follows_the_doors() -> void:
	assert_eq(PlaceGraph.next_place("appartement_akan", "hall_tour"), "palier_11")
	assert_eq(PlaceGraph.next_place("palier_11", "hall_tour"), "palier_7")
	assert_eq(PlaceGraph.next_place("hall_tour", "hall_tour"), "hall_tour")
	assert_eq(PlaceGraph.next_place("appartement_akan", "licorne"), "")


func test_the_beacon_floats_above_a_character_to_talk_to() -> void:
	var home := await _make_zone("appartement_akan")
	var guide: QuestGuide = home.get_node("QuestGuide")
	var mother: Npc = home.get_node("Daronne")
	assert_true(guide.beacon_visible())
	var at := guide.beacon_position()
	assert_almost_eq(
		Vector2(at.x, at.z), Vector2(mother.position.x, mother.position.z), Vector2.ONE * 0.01
	)
	assert_gt(at.y, 1.8, "au-dessus de la tête")


func test_the_beacon_points_at_the_door_towards_another_place() -> void:
	for step: Array in [["TALK", "daronne"], ["USE", "boire"], ["USE", "manger"]]:
		GameState.quests.notify(step[0], step[1])
	GameState.give("bidon_vide")
	assert_true(GameState.quests.is_step(GameState.FIRST_QUEST, "ascenseur"))
	var home := await _make_zone("appartement_akan")
	var guide: QuestGuide = home.get_node("QuestGuide")
	var exit := home.marker_position("porte")
	var at := guide.beacon_position()
	assert_almost_eq(Vector2(at.x, at.z), Vector2(exit.x, exit.z), Vector2.ONE * 0.01)


func test_no_beacon_for_an_objective_without_a_place() -> void:
	GameState.quests.notify("TALK", "daronne")
	var home := await _make_zone("appartement_akan")
	var guide: QuestGuide = home.get_node("QuestGuide")
	assert_false(guide.beacon_visible(), "boire n'a pas de lieu")


func _make_zone(place: String) -> Zone:
	var zone := Zone.create(place)
	add_child_autofree(zone)
	await wait_process_frames(3)
	return zone
