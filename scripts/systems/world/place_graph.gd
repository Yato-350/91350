class_name PlaceGraph
## Le graphe des lieux du jeu (zones et intérieurs) : chaque porte est une sortie d'un
## lieu vers un autre. Sert à vérifier qu'aucun lieu n'est hors d'atteinte et qu'aucun
## ne piège Akan.


## Tous les lieux connus.
static func places() -> Array[String]:
	var found: Array[String] = []
	for type: String in ["zones", "interiors"]:
		for place: String in DataRegistry.all(type):
			found.append(place)
	return found


## Lieu → lieux où mènent ses portes.
static func exits() -> Dictionary:
	var graph := {}
	for type: String in ["zones", "interiors"]:
		var definitions := DataRegistry.all(type)
		for place: String in definitions:
			var targets: Array[String] = []
			for door: Dictionary in definitions[place].get("doors", []):
				targets.append(str(door["to"]).get_slice(GameState.MARKER_SEPARATOR, 0))
			graph[place] = targets
	return graph


## Les lieux atteignables depuis `start` (lui compris), en passant les portes.
static func reachable(start: String) -> Array[String]:
	var graph := exits()
	var reached: Array[String] = []
	if not graph.has(start):
		return reached
	var pending: Array[String] = [start]
	while not pending.is_empty():
		var place: String = pending.pop_back()
		if place in reached:
			continue
		reached.append(place)
		for target: String in graph.get(place, []):
			if not target in reached:
				pending.append(target)
	return reached
