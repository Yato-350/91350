extends GutTest
## Le graphe des lieux : chaque porte est une sortie. Aucun lieu ne doit être hors
## d'atteinte, ni piéger Akan (on doit toujours pouvoir rentrer chez lui).

const HOME := "appartement_akan"


func test_every_place_is_reachable_from_home() -> void:
	var reached := PlaceGraph.reachable(HOME)
	for place: String in PlaceGraph.places():
		assert_has(reached, place, "%s injoignable depuis l'appartement" % place)


func test_home_is_reachable_from_every_place() -> void:
	for place: String in PlaceGraph.places():
		assert_has(PlaceGraph.reachable(place), HOME, "%s piège Akan" % place)


func test_exits_follow_the_doors() -> void:
	var exits := PlaceGraph.exits()
	assert_has(exits["appartement_akan"], "palier_11")
	assert_has(exits["hall_tour"], "grigny2")
	assert_has(exits["grigny2"], "hall_tour")
	assert_eq(PlaceGraph.reachable("licorne"), [] as Array[String])
