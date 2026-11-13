class_name Main
extends Node
## Scène principale : charge une zone dans le compositeur et gère les commandes globales.
##
## Mode capture d'écran, pour vérifier un rendu sans jouer :
##   godot --path . -- --screenshot res://scenes/zones/test_zone.tscn
## charge la scène, attend quelques images, écrit build/screenshots/<scène>.png et quitte.

const DEFAULT_ZONE := "res://scenes/zones/test_zone.tscn"
const COLOR_FADE_SECONDS := 1.5
## Durée du fondu au noir, à l'aller comme au retour, quand Akan change de lieu.
const TRAVEL_FADE_SECONDS := 0.2
const READY_MARKER := "[91350] prêt"
const SCREENSHOT_ARGUMENT := "--screenshot"
## « --hour 23.5 » : l'heure du jeu au moment de la capture.
const HOUR_ARGUMENT := "--hour"
const SCREENSHOT_DIR := "res://build/screenshots"
const SCREENSHOT_FRAMES := 30
## « zone:<identifiant> » désigne un lieu des données plutôt qu'un fichier de scène.
const ZONE_PREFIX := GameState.ZONE_PREFIX

## Là où commence le jeu : la zone d'essai (main.tscn, pour les tests), ou l'appartement
## d'Akan pour une vraie partie (game.tscn).
@export var start_place := DEFAULT_ZONE
## Vrai : une nouvelle partie commence (première quête, horloge qui tourne).
@export var new_game := false

var _colour_enabled := true
var _traveling := false

@onready var _pixel_view: PixelView = $PixelView
@onready var _ui: CanvasLayer = $UI
@onready var _fade: ColorRect = $Overlay/Fade


## Rend le chemin res:// de la scène demandée par « --screenshot <scène> », ou "".
static func parse_screenshot_scene(args: PackedStringArray) -> String:
	var index := args.find(SCREENSHOT_ARGUMENT)
	if index == -1 or index + 1 >= args.size() or args[index + 1].begins_with("--"):
		return ""
	var path := args[index + 1]
	if path.begins_with("res://") or path.begins_with(ZONE_PREFIX):
		return path
	return "res://" + path


## L'heure demandée par « --hour <h> » (en heures), ou -1 si absente ou illisible.
static func parse_hour(args: PackedStringArray) -> float:
	var index := args.find(HOUR_ARGUMENT)
	if index == -1 or index + 1 >= args.size() or not args[index + 1].is_valid_float():
		return -1.0
	return args[index + 1].to_float()


func _ready() -> void:
	_pixel_view.scale_changed.connect(func(_scale: int) -> void: _layout_ui())
	_pixel_view.resized.connect(_layout_ui)
	_layout_ui()
	EventBus.travel_requested.connect(_on_travel_requested)
	var screenshot_scene := parse_screenshot_scene(OS.get_cmdline_user_args())
	if not screenshot_scene.is_empty():
		_run_screenshot_mode(screenshot_scene)
		return
	if new_game:
		GameState.new_game()
		GameState.quests.start(GameState.FIRST_QUEST)
		GameState.playing = true
	travel_to(start_place)
	await get_tree().process_frame
	print(READY_MARKER)


func _input(event: InputEvent) -> void:
	InputHints.note_event(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		save_game()
	elif event.is_action_pressed(&"quick_load"):
		load_game()
	elif event.is_action_pressed(&"toggle_fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed(&"debug_toggle_color"):
		_colour_enabled = not _colour_enabled
		var target := 1.0 if _colour_enabled else 0.0
		EventBus.saturation_change_requested.emit(target, COLOR_FADE_SECONDS)


## Charge un lieu et y place Akan. `ref` est un chemin de scène ou « zone:<id>[@repère] » ;
## `position` ([x, y, z]) remplace le point d'arrivée, pour reprendre une sauvegarde.
## Rend false, sans rien changer, si le lieu ne se charge pas.
func travel_to(ref: String, position: Array = []) -> bool:
	if not load_zone(ref):
		return false
	var zone := _pixel_view.get_zone() as Zone
	GameState.enter(ref, zone.territory_id if zone != null else "")
	_pixel_view.zoom = zone.get_zoom() if zone != null else 1
	var player := get_player()
	if player != null and position.size() == 3:
		player.teleport(Vector3(position[0], position[1], position[2]))
	return true


## Une porte a été franchie : fondu au noir, changement de lieu, retour de l'image.
func _on_travel_requested(target: String) -> void:
	if _traveling:
		return
	_traveling = true
	await _fade_to(1.0)
	travel_to(ZONE_PREFIX + target)
	await _fade_to(0.0)
	_traveling = false


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, ^"color:a", alpha, TRAVEL_FADE_SECONDS)
	await tween.finished


func get_player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player


## Sauvegarde la partie, avec l'endroit exact où se tient Akan.
func save_game(slot: int = 0) -> bool:
	var player := get_player()
	if player != null:
		var at := player.global_position
		GameState.saved_position = [at.x, at.y, at.z]
	return SaveManager.save_game(slot)


## Relit la partie, puis recharge le lieu où elle a été sauvegardée.
func load_game(slot: int = 0) -> bool:
	if not SaveManager.load_game(slot):
		return false
	return travel_to(GameState.location, GameState.saved_position)


## Remplace la zone affichée. Rend false, sans rien changer, si la scène ne se charge pas.
func load_zone(path: String) -> bool:
	var zone: Node3D
	if path.begins_with(ZONE_PREFIX):
		# Zone.create journalise lui-même une zone inconnue.
		zone = Zone.create(path.trim_prefix(ZONE_PREFIX))
	else:
		zone = _instantiate_scene(path)
		if zone == null:
			push_error("Scène de zone introuvable ou invalide : %s" % path)
	if zone == null:
		return false
	_pixel_view.set_zone(zone)
	return true


func _instantiate_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var scene := load(path) as PackedScene
	var root := scene.instantiate() if scene != null else null
	var zone := root as Node3D
	if zone == null and root != null:
		root.free()
	return zone


func save_screenshot(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return get_viewport().get_texture().get_image().save_png(path)


func _run_screenshot_mode(scene_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Le mode --screenshot a besoin d'un rendu : ne pas le lancer avec --headless.")
		get_tree().quit(1)
		return
	var hour := parse_hour(OS.get_cmdline_user_args())
	if hour >= 0.0:
		GameState.clock.minutes = hour * GameClock.MINUTES_PER_HOUR
	if not travel_to(scene_path):
		get_tree().quit(1)
		return
	for i: int in SCREENSHOT_FRAMES:
		await get_tree().process_frame
	# « zone:grigny2@-48.7,-34.7 » n'a pas d'extension : seul un fichier de scène en perd une.
	var file_name := scene_path.get_file()
	if not scene_path.begins_with(ZONE_PREFIX):
		file_name = file_name.get_basename()
	file_name = file_name.replace(":", "_")
	if hour >= 0.0:
		var args := OS.get_cmdline_user_args()
		file_name += "_%sh" % args[args.find(HOUR_ARGUMENT) + 1]
	var path := SCREENSHOT_DIR.path_join(file_name + ".png")
	if save_screenshot(path) != OK:
		printerr("Capture impossible : %s" % path)
		get_tree().quit(1)
		return
	print("Capture enregistrée : %s" % ProjectSettings.globalize_path(path))
	get_tree().quit(0)


# L'interface est dessinée en 640×360 puis agrandie du même facteur entier que le monde.
func _layout_ui() -> void:
	var pixel_scale := maxi(1, _pixel_view.get_pixel_scale())
	_ui.scale = Vector2.ONE * pixel_scale
	for child: Node in _ui.get_children():
		var layer := child as Control
		if layer != null:
			layer.position = Vector2.ZERO
			layer.size = (_pixel_view.size / pixel_scale).ceil()


func _toggle_fullscreen() -> void:
	var window := get_window()
	var is_fullscreen := window.mode == Window.MODE_FULLSCREEN
	window.mode = Window.MODE_WINDOWED if is_fullscreen else Window.MODE_FULLSCREEN
