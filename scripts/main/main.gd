class_name Main
extends Node
## Scène principale : charge une zone dans le compositeur et gère les commandes globales.
##
## Mode capture d'écran, pour vérifier un rendu sans jouer :
##   godot --path . -- --screenshot res://scenes/zones/test_zone.tscn
## charge la scène, attend quelques images, écrit build/screenshots/<scène>.png et quitte.

const DEFAULT_ZONE := "res://scenes/zones/test_zone.tscn"
const COLOR_FADE_SECONDS := 1.5
const READY_MARKER := "[91350] prêt"
const SCREENSHOT_ARGUMENT := "--screenshot"
const SCREENSHOT_DIR := "res://build/screenshots"
const SCREENSHOT_FRAMES := 30

var _colour_enabled := true

@onready var _pixel_view: PixelView = $PixelView


## Rend le chemin res:// de la scène demandée par « --screenshot <scène> », ou "".
static func parse_screenshot_scene(args: PackedStringArray) -> String:
	var index := args.find(SCREENSHOT_ARGUMENT)
	if index == -1 or index + 1 >= args.size() or args[index + 1].begins_with("--"):
		return ""
	var path := args[index + 1]
	return path if path.begins_with("res://") else "res://" + path


func _ready() -> void:
	var screenshot_scene := parse_screenshot_scene(OS.get_cmdline_user_args())
	if not screenshot_scene.is_empty():
		_run_screenshot_mode(screenshot_scene)
		return
	load_zone(DEFAULT_ZONE)
	await get_tree().process_frame
	print(READY_MARKER)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		SaveManager.save_game()
	elif event.is_action_pressed(&"quick_load"):
		SaveManager.load_game()
	elif event.is_action_pressed(&"toggle_fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed(&"debug_toggle_color"):
		_colour_enabled = not _colour_enabled
		var target := 1.0 if _colour_enabled else 0.0
		EventBus.saturation_change_requested.emit(target, COLOR_FADE_SECONDS)


## Remplace la zone affichée. Rend false, sans rien changer, si la scène ne se charge pas.
func load_zone(path: String) -> bool:
	if not ResourceLoader.exists(path, "PackedScene"):
		push_error("Zone introuvable : %s" % path)
		return false
	var scene: PackedScene = load(path)
	var zone := scene.instantiate() as Node3D
	if zone == null:
		push_error("La zone doit avoir une racine Node3D : %s" % path)
		return false
	_pixel_view.set_zone(zone)
	return true


func save_screenshot(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return get_viewport().get_texture().get_image().save_png(path)


func _run_screenshot_mode(scene_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Le mode --screenshot a besoin d'un rendu : ne pas le lancer avec --headless.")
		get_tree().quit(1)
		return
	if not load_zone(scene_path):
		get_tree().quit(1)
		return
	for i: int in SCREENSHOT_FRAMES:
		await get_tree().process_frame
	var path := SCREENSHOT_DIR.path_join(scene_path.get_file().get_basename() + ".png")
	if save_screenshot(path) != OK:
		printerr("Capture impossible : %s" % path)
		get_tree().quit(1)
		return
	print("Capture enregistrée : %s" % ProjectSettings.globalize_path(path))
	get_tree().quit(0)


func _toggle_fullscreen() -> void:
	var window := get_window()
	var is_fullscreen := window.mode == Window.MODE_FULLSCREEN
	window.mode = Window.MODE_WINDOWED if is_fullscreen else Window.MODE_FULLSCREEN
