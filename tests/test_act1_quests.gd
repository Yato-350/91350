extends GutTest
## Les quêtes de l'acte 1, telles qu'écrites dans data/quests/ : chaque cible existe, la
## chaîne des quêtes va de la première à la dernière, et le rythme respire.

const OBJECTIVES: Array[String] = [
	"TALK",
	"GOTO",
	"COLLECT",
	"DELIVER",
	"USE",
	"PUBLISH",
	"SABOTAGE",
	"HACK",
	"ESCORT",
	"STEALTH",
	"DEFEND",
	"NEUTRALIZE"
]
const HIGH := 0.7


func test_every_step_points_at_something_that_exists() -> void:
	var quests := DataRegistry.all("quests")
	assert_gt(quests.size(), 0)
	var characters := DataRegistry.all("characters")
	var items := DataRegistry.all("items")
	for quest_id: String in quests:
		for step: Dictionary in quests[quest_id]["steps"]:
			var where := "%s:%s" % [quest_id, step["id"]]
			assert_has(OBJECTIVES, step["type"], where)
			var target: String = step["target"]
			match step["type"]:
				"TALK", "DELIVER":
					assert_true(characters.has(target), "%s → %s" % [where, target])
				"COLLECT":
					assert_true(items.has(target), "%s → %s" % [where, target])
				"GOTO":
					assert_true(_place_exists(target), "%s → %s" % [where, target])
			if step.has("where"):
				assert_true(_place_exists(step["where"]), "%s → %s" % [where, step["where"]])


func test_the_chain_starts_every_quest_of_the_act() -> void:
	var quests := DataRegistry.all("quests")
	var started: Array[String] = [GameState.FIRST_QUEST]
	var index := 0
	while index < started.size():
		var quest: Dictionary = quests.get(started[index], {})
		var effects: Array = [quest.get("rewards", {})]
		for step: Dictionary in quest.get("steps", []):
			effects.append(step.get("effects", {}))
		for effect: Dictionary in effects:
			for next: String in effect.get("start", []):
				if not next in started:
					started.append(next)
		index += 1
	for quest_id: String in quests:
		assert_has(started, quest_id, "%s n'est jamais lancée" % quest_id)


func test_the_act_breathes_between_its_peaks() -> void:
	var beats := _beats()
	assert_eq(beats[0]["type"], "teach", "l'acte s'ouvre en apprenant")
	var run := 0
	for index: int in beats.size():
		run = run + 1 if beats[index]["intensity"] >= HIGH else 0
		assert_lte(run, 2, "trop de moments intenses à la suite : %s" % beats[index]["quest"])
		if beats[index]["type"] == "climax":
			assert_eq(beats[index - 1]["type"], "rest", "un temps de repos avant le sommet")


# Les quêtes dans l'ordre où l'histoire les lance.
func _beats() -> Array[Dictionary]:
	var quests := DataRegistry.all("quests")
	var beats: Array[Dictionary] = []
	var current := GameState.FIRST_QUEST
	while not current.is_empty() and quests.has(current):
		var quest: Dictionary = quests[current]
		var beat: Dictionary = quest["beat"].duplicate()
		beat["quest"] = current
		beats.append(beat)
		var next: Array = quest.get("rewards", {}).get("start", [])
		current = next[0] if not next.is_empty() else ""
	return beats


func _place_exists(ref: String) -> bool:
	var place := ref.get_slice(":", 0)
	var definition := DataRegistry.entry("zones", place)
	if definition.is_empty():
		definition = DataRegistry.entry("interiors", place)
	if definition.is_empty():
		return false
	if not ref.contains(":"):
		return true
	var marker := ref.get_slice(":", 1)
	var markers: Dictionary = definition.get("markers", {})
	return marker in markers.keys() or marker in markers.values()
