extends GutTest
## Exige un vrai rendu : lancé par « tools/check.sh render ».

const SCENE := preload("res://scenes/main/main.tscn")
const OUTPUT := "user://essai_capture.png"

# GUT déclare cette méthode sans type de retour : la signature doit rester identique.
@warning_ignore("untyped_declaration")
func should_skip_script():
	if DisplayServer.get_name() == "headless":
		return "rendu indisponible en --headless (lancer tools/check.sh render)"
	return false


func after_each() -> void:
	DirAccess.remove_absolute(OUTPUT)


func test_screenshot_is_written() -> void:
	var main: Main = SCENE.instantiate()
	add_child_autofree(main)
	await wait_process_frames(6)
	assert_eq(main.save_screenshot(OUTPUT), OK)
	assert_file_exists(OUTPUT)
	var image := Image.load_from_file(OUTPUT)
	assert_eq(image.get_size(), get_window().size)
	var colors := {}
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			colors[image.get_pixel(x, y).to_rgba32()] = true
	assert_gte(colors.size(), 4, "la capture ne doit pas être unie")
