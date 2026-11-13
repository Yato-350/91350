class_name ItemIcon
## Icônes d'inventaire, produites par tools/build_voxels.py à partir des modèles voxel.

const PATH := "res://assets/icons/items/%s.png"


## L'icône de l'objet, ou null s'il n'en a pas (ou si `item_id` est vide).
static func of(item_id: String) -> Texture2D:
	var path := PATH % item_id
	if item_id.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
