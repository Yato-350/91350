extends GutTest
## Captures des écrans d'interface, à regarder après un changement visuel :
## build/screenshots/ui_*.png. Exige un vrai rendu : lancé par « tools/check.sh render ».

const SCENE := preload("res://scenes/main/main.tscn")
const OUTPUT := "res://build/screenshots/ui_%s.png"
const SETTLE_FRAMES := 8

# GUT déclare cette méthode sans type de retour : la signature doit rester identique.
@warning_ignore("untyped_declaration")
func should_skip_script():
	if DisplayServer.get_name() == "headless":
		return "rendu indisponible en --headless (lancer tools/check.sh render)"
	return false


func before_each() -> void:
	GameState.new_game()
	_show_test_runner(false)


func after_each() -> void:
	get_tree().paused = false
	_show_test_runner(true)


func test_the_bag_screen_is_drawn_over_the_game() -> void:
	var main := await _make_main("zone:appartement_akan")
	var closed := get_viewport().get_texture().get_image()
	GameState.give("bouteille_eau", 3)
	GameState.give("baguette", 1)
	GameState.give("bidon_vide", 1)
	GameState.give("trousse_soins", 2)
	GameState.inventory.assign_quick_slot(0, "bouteille_eau")
	var screens: Screens = main.get_node("UI/Screens")
	screens.open("Inventory")
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq(main.save_screenshot(OUTPUT % "inventory"), OK)
	var opened := get_viewport().get_texture().get_image()
	assert_gt(
		_changed_pixels(closed, opened), 2000, "le panneau du sac couvre une partie de l'écran"
	)


func test_the_dialogue_balloon_is_drawn_over_the_game() -> void:
	var main := await _make_main("zone:appartement_akan@cuisine")
	var closed := get_viewport().get_texture().get_image()
	EventBus.dialogue_requested.emit("res://tests/dialogue/essai.dialogue", "start")
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq(main.save_screenshot(OUTPUT % "dialogue"), OK)
	var opened := get_viewport().get_texture().get_image()
	assert_gt(_changed_pixels(closed, opened), 2000, "la bulle couvre le bas de l'écran")


func _make_main(place: String) -> Main:
	var main: Main = SCENE.instantiate()
	add_child_autofree(main)
	await wait_process_frames(2)
	main.travel_to(place)
	await wait_process_frames(SETTLE_FRAMES)
	return main


func _changed_pixels(before: Image, after: Image) -> int:
	var changed := 0
	for y: int in range(0, before.get_height(), 2):
		for x: int in range(0, before.get_width(), 2):
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				changed += 1
	return changed


# Le panneau de GUT recouvrirait la moitié de la capture.
func _show_test_runner(shown: bool) -> void:
	var layer := get_tree().root.find_child("GutLayer", true, false) as CanvasLayer
	if layer != null:
		layer.visible = shown
