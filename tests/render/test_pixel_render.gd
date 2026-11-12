extends GutTest
## Tests qui exigent un vrai rendu (OpenGL) : lancés par « tools/check.sh render ».

const SCENE := preload("res://scenes/main/pixel_view.tscn")
const SETTLE_FRAMES := 4

var _view: PixelView
var _palette: Dictionary

# GUT déclare cette méthode sans type de retour : la signature doit rester identique.
@warning_ignore("untyped_declaration")
func should_skip_script():
	if DisplayServer.get_name() == "headless":
		return "rendu indisponible en --headless (lancer tools/check.sh render)"
	return false


func before_each() -> void:
	_palette = Palette.load_colors()
	_view = SCENE.instantiate()
	add_child_autofree(_view)
	_view.size = Vector2(1280, 720)
	_view.set_zone(_make_world())
	await wait_process_frames(SETTLE_FRAMES)


func test_every_pixel_is_a_palette_color() -> void:
	assert_eq(_count_off_palette(_view.get_low_res_image()), 0)


func test_outline_draws_the_darkest_color() -> void:
	var outline_color: Color = _palette["noir"]
	assert_gt(_count_color(_view.get_low_res_image(), outline_color), 0)
	var outline: Node3D = _view.get_node("Container/World/Outline")
	outline.visible = false
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq(_count_color(_view.get_low_res_image(), outline_color), 0)


func test_outline_ignores_the_frame_border() -> void:
	var image := _view.get_low_res_image()
	var outline_color := _rgb(_palette["noir"])
	var on_border := 0
	for x: int in image.get_width():
		for y: int in [0, image.get_height() - 1]:
			if _rgb(image.get_pixel(x, y)) == outline_color:
				on_border += 1
	for y: int in image.get_height():
		for x: int in [0, image.get_width() - 1]:
			if _rgb(image.get_pixel(x, y)) == outline_color:
				on_border += 1
	assert_eq(on_border, 0, "le shader ne doit pas lire de voisin hors de l'image")


func test_grey_and_colour_differ() -> void:
	var coloured := _view.get_low_res_image()
	_view.saturation = 0.0
	await wait_process_frames(SETTLE_FRAMES)
	var grey := _view.get_low_res_image()
	assert_ne(coloured.get_data(), grey.get_data())
	assert_eq(_count_off_palette(grey), 0)


## Scène claire : sol et cube gris clair, cube rouge. Sans contours, rien n'y est noir.
func _make_world() -> Node3D:
	var world := Node3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = _palette["beton_5"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	world.add_child(sun)
	world.add_child(_make_box(Vector3(160.0, 0.2, 160.0), Vector3(0.0, -0.1, 0.0), "beton_5"))
	world.add_child(_make_box(Vector3(2.0, 2.0, 2.0), Vector3(0.0, 1.0, 0.0), "blanc"))
	world.add_child(_make_box(Vector3.ONE, Vector3(3.0, 0.5, 2.0), "rouge_propagande"))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	world.add_child(camera)
	camera.position = camera.basis.z * 40.0
	return world


func _make_box(box_size: Vector3, at: Vector3, color_id: String) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _palette[color_id]
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	return instance


func _count_off_palette(image: Image) -> int:
	var allowed := {}
	for color: Color in _palette.values():
		allowed[_rgb(color)] = true
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if not allowed.has(_rgb(image.get_pixel(x, y))):
				count += 1
	return count


func _count_color(image: Image, color: Color) -> int:
	var wanted := _rgb(color)
	var count := 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if _rgb(image.get_pixel(x, y)) == wanted:
				count += 1
	return count


func _rgb(color: Color) -> int:
	return (color.r8 << 16) | (color.g8 << 8) | color.b8
