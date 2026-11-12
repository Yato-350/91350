class_name DataRegistry
## Lit les données du jeu (data/<type>/*.json) et les garde en mémoire.
##
## Un fichier contient soit une fiche ({"id": …}), soit une liste de fiches sous une
## clé du nom du type ({"items": [ {"id": …}, … ]}).

const ROOT := "res://data"

static var _cache := {}


## Toutes les fiches d'un type, par identifiant.
static func all(type: String) -> Dictionary:
	if not _cache.has(type):
		_cache[type] = load_dir(ROOT.path_join(type), type)
	return _cache[type]


## La fiche demandée, ou {} si elle n'existe pas.
static func entry(type: String, id: String) -> Dictionary:
	return all(type).get(id, {})


static func clear_cache() -> void:
	_cache.clear()


static func load_dir(path: String, type: String) -> Dictionary:
	var entries := {}
	if not DirAccess.dir_exists_absolute(path):
		return entries
	for file_name: String in DirAccess.get_files_at(path):
		if file_name.get_extension() != "json":
			continue
		var file_path := path.path_join(file_name)
		var json := JSON.new()
		if (
			json.parse(FileAccess.get_file_as_string(file_path)) != OK
			or not json.data is Dictionary
		):
			push_error("Données illisibles : %s" % file_path)
			continue
		var data: Dictionary = json.data
		var listed: Variant = data.get(type)
		var records: Array = listed if listed is Array else [data]
		for record: Variant in records:
			if record is Dictionary and record.get("id") is String:
				entries[record["id"]] = record
			else:
				push_error("Fiche sans identifiant dans %s" % file_path)
	return entries
