extends SceneTree
## Charge chaque script, scène et ressource du projet : l'import seul ne signale pas
## les erreurs de GDScript. Sort avec le code 1 si une ressource ne se charge pas.

const ROOTS: Array[String] = [
	"res://scripts", "res://scenes", "res://tests", "res://tools", "res://assets", "res://shaders"
]
const EXTENSIONS: Array[String] = ["gd", "tscn", "tres", "gdshader"]


func _initialize() -> void:
	var failures := 0
	for root: String in ROOTS:
		for path: String in _list_files(root):
			if not _loads(path):
				printerr("Échec du chargement : ", path)
				failures += 1
	quit(1 if failures > 0 else 0)


func _loads(path: String) -> bool:
	var resource := ResourceLoader.load(path)
	if resource == null:
		return false
	var script := resource as GDScript
	return script == null or script.can_instantiate() or script.is_abstract()


func _list_files(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return files
	for name: String in dir.get_files():
		if name.get_extension() in EXTENSIONS:
			files.append(dir_path.path_join(name))
	for name: String in dir.get_directories():
		files.append_array(_list_files(dir_path.path_join(name)))
	return files
