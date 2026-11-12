extends Node
## Écrit et relit les sauvegardes sur le disque.
##
## Chaque nœud du groupe « saveable » fournit :
##   save_id: StringName                      identifiant stable dans le fichier
##   save_state() -> Dictionary               valeurs compatibles JSON
##   load_state(state: Dictionary) -> void

const SAVEABLE_GROUP := &"saveable"
const TEMP_SUFFIX := ".tmp"

var save_dir: String = "user://saves"


func slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int = 0) -> bool:
	var systems := {}
	for node: Node in get_tree().get_nodes_in_group(SAVEABLE_GROUP):
		var id := _save_id(node)
		if id.is_empty() or not node.has_method(&"save_state"):
			push_error("Nœud sauvegardable sans save_id ou sans save_state : %s" % node.get_path())
			return false
		if systems.has(id):
			push_error("Deux nœuds sauvegardables portent le même save_id : %s" % id)
			return false
		systems[id] = node.call(&"save_state")
	var text := SaveCodec.encode(systems, Time.get_datetime_string_from_system(true))

	# Écriture dans un fichier temporaire puis renommage : une coupure en cours
	# d'écriture ne laisse jamais une sauvegarde à moitié écrite.
	DirAccess.make_dir_recursive_absolute(save_dir)
	var temp_path := slot_path(slot) + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Sauvegarde impossible : %s" % temp_path)
		return false
	file.store_string(text)
	file.close()
	if DirAccess.rename_absolute(temp_path, slot_path(slot)) != OK:
		push_warning("Sauvegarde impossible : %s" % slot_path(slot))
		return false
	EventBus.game_saved.emit(slot)
	return true


## Ne modifie rien si la sauvegarde manque ou est illisible.
func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		return false
	var data := SaveCodec.decode(FileAccess.get_file_as_string(slot_path(slot)))
	if data.is_empty():
		push_warning("Sauvegarde illisible : %s" % slot_path(slot))
		return false
	var systems: Dictionary = data["systems"]
	for node: Node in get_tree().get_nodes_in_group(SAVEABLE_GROUP):
		var state: Variant = systems.get(_save_id(node))
		if state is Dictionary:
			node.call(&"load_state", state)
	EventBus.game_loaded.emit(slot)
	return true


func _save_id(node: Node) -> String:
	var id: Variant = node.get(&"save_id")
	return "" if id == null else str(id)
