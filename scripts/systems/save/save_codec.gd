class_name SaveCodec
## Encodage des sauvegardes : du JSON versionné, migré d'une version à la suivante.
## Logique pure, sans nœud ni fichier, pour être testée facilement.

const CURRENT_VERSION := 1


## Migrations des anciens formats : version de départ → Callable(Dictionary) -> Dictionary.
## Vide tant que le format n'a pas changé.
static func migrations() -> Dictionary:
	return {}


static func encode(systems: Dictionary, saved_at: String) -> String:
	var data := {"save_version": CURRENT_VERSION, "saved_at": saved_at, "systems": systems}
	return JSON.stringify(data, "\t")


## Rend les données migrées vers la version courante, ou {} si le texte n'est pas
## une sauvegarde lisible.
static func decode(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	var version: Variant = data.get("save_version")
	if not (version is float or version is int) or not data.get("systems") is Dictionary:
		return {}
	# Le JSON de Godot lit tous les nombres en flottants.
	data["save_version"] = int(version)
	return migrate(data, migrations(), CURRENT_VERSION)


## Applique steps[v] pour chaque version v, de celle des données jusqu'à la cible.
## Rend {} si une étape manque ou si les données viennent d'une version plus récente.
static func migrate(data: Dictionary, steps: Dictionary, target_version: int) -> Dictionary:
	var version: int = data.get("save_version", 0)
	if version < 1 or version > target_version:
		return {}
	while version < target_version:
		if not steps.has(version):
			return {}
		var step: Callable = steps[version]
		data = step.call(data)
		version += 1
		data["save_version"] = version
	return data


## Lit un nombre d'un état relu ; `fallback` si la clé manque ou n'est pas un nombre.
static func number(state: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = state.get(key)
	return float(value) if value is float or value is int else fallback


static func text(state: Dictionary, key: String, fallback: String) -> String:
	var value: Variant = state.get(key)
	return value if value is String else fallback


static func flag(state: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = state.get(key)
	return value if value is bool else fallback


static func table(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key)
	return value if value is Dictionary else {}


static func list(state: Dictionary, key: String) -> Array:
	var value: Variant = state.get(key)
	return value if value is Array else []
