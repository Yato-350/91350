extends GutTest
## Chaque fichier de dialogue/ se compile et contient l'entrée « start » ou celles que les
## lieux et les quêtes lui demandent.

const FOLDER := "res://dialogue"


func test_every_dialogue_file_compiles() -> void:
	var files := DirAccess.get_files_at(FOLDER)
	var count := 0
	for file_name: String in files:
		if file_name.get_extension() != "dialogue":
			continue
		count += 1
		var resource := load(FOLDER.path_join(file_name)) as DialogueResource
		assert_not_null(resource, file_name)
		if resource != null:
			assert_gt(resource.lines.size(), 0, file_name)
	assert_gt(count, 5)


func test_every_requested_cue_exists() -> void:
	var requests: Array[Array] = []
	for type: String in ["zones", "interiors"]:
		var places := DataRegistry.all(type)
		for place: String in places:
			for npc: Dictionary in places[place].get("npcs", []):
				if npc.has("dialogue"):
					requests.append([npc["dialogue"], npc.get("cue", "start")])
			for door: Dictionary in places[place].get("doors", []):
				if door.has("dialogue"):
					requests.append(door["dialogue"])
	var quests := DataRegistry.all("quests")
	for quest: String in quests:
		for step: Dictionary in quests[quest]["steps"]:
			if step.has("dialogue"):
				requests.append(step["dialogue"])
	assert_gt(requests.size(), 5)
	for request: Array in requests:
		var path := FOLDER.path_join("%s.dialogue" % request[0])
		var resource := load(path) as DialogueResource
		assert_not_null(resource, path)
		if resource != null:
			assert_has(resource.get_cues(), request[1], "%s ~ %s" % request)
