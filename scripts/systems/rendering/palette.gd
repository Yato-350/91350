class_name Palette
## Palette unique du jeu (32 couleurs au plus), lue dans assets_src/palette.json.
## Le shader de rendu et les outils d'assets partagent ce même fichier.

const PATH := "res://assets_src/palette.json"
const MAX_COLORS := 32


## Rend les couleurs par identifiant, dans l'ordre du fichier.
## Dictionnaire vide (et erreur journalisée) si le fichier manque ou est invalide.
static func load_colors(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Palette introuvable : %s" % path)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("colors") is Array:
		push_error("Palette illisible : %s" % path)
		return {}
	var entries: Array = data["colors"]
	if entries.size() > MAX_COLORS:
		push_error("Palette trop grande (%d couleurs) : %s" % [entries.size(), path])
		return {}
	var colors := {}
	for entry: Variant in entries:
		if not entry is Dictionary or not Color.html_is_valid(str(entry.get("hex", ""))):
			push_error("Couleur invalide dans la palette : %s" % path)
			return {}
		colors[str(entry.get("id", ""))] = Color.html(str(entry["hex"]))
	return colors
