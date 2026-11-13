extends GutTest
## Défendre un lieu : les Vigiles descendent par vagues ; chacun mis hors d'état compte.

const QUESTS := {
	"defense_essai":
	{
		"id": "defense_essai",
		"steps":
		[
			{
				"id": "tenir",
				"type": "DEFEND",
				"target": "essai_defense",
				"count": 3,
				"waves": [1, 2],
				"spawn": "entree",
				"enemy": "intervention",
			},
			{"id": "fin", "type": "TALK", "target": "personne"},
		],
	},
}
const PLAN := {
	"id": "essai_defense",
	"territory": "grigny2",
	"plan": ["##########", "#a......e#", "#........#", "##########"],
	"markers": {"a": "default", "e": "entree"},
}


func before_each() -> void:
	GameState.new_game()
	GameState.quests = QuestLog.new(QUESTS)
	GameState.connect_quests()
	GameState.quests.start("defense_essai")


func after_each() -> void:
	GameState.new_game()


func test_the_waves_come_one_after_the_other() -> void:
	var zone := await _make()
	var first := _standing(zone)
	assert_eq(first.size(), 1, "première vague")
	assert_eq(first[0].state, Vigile.State.ALERT, "il vient pour Akan")
	first[0].knock_out()
	await wait_process_frames(2)
	assert_eq(GameState.quests.progress("defense_essai"), 1)
	var second := _standing(zone)
	assert_eq(second.size(), 2, "deuxième vague")
	for vigile: Vigile in second:
		vigile.knock_out()
	await wait_process_frames(2)
	assert_true(GameState.quests.is_step("defense_essai", "fin"), "le lieu a tenu")
	assert_eq(_standing(zone).size(), 0, "plus personne ne descend")


func test_a_defense_resumes_where_it_stopped() -> void:
	GameState.objective("DEFEND", "essai_defense")
	var zone := await _make()
	assert_eq(_standing(zone).size(), 2, "la première vague est déjà tombée")


func test_nothing_comes_when_no_defense_is_due() -> void:
	GameState.quests = QuestLog.new({})
	GameState.connect_quests()
	var zone := await _make()
	assert_eq(_standing(zone).size(), 0)


func _make() -> Zone:
	var zone := Zone.from_definition("essai_defense", PLAN, true)
	add_child_autofree(zone)
	await wait_process_frames(2)
	return zone


func _standing(zone: Zone) -> Array[Vigile]:
	var found: Array[Vigile] = []
	for node: Node in zone.find_children("*", "CharacterBody3D", true, false):
		var vigile := node as Vigile
		if vigile != null and vigile.state != Vigile.State.KNOCKED_OUT:
			found.append(vigile)
	return found
