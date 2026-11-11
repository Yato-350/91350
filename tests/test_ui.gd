extends GutTest

const SCENE := preload("res://scenes/main/main.tscn")
const STRINGS := "res://locale/strings.csv"
const FONT := "res://assets/fonts/Tiny5-Regular.ttf"
const FRENCH_GLYPHS := "àâäçéèêëîïôöùûüÿœæÀÂÇÉÈÊËÎÏÔÙÛÜŒ«»’…—·"


func before_all() -> void:
	TranslationServer.set_locale("fr")


func test_every_key_is_translated_in_french() -> void:
	var keys := _translation_keys()
	assert_gt(keys.size(), 0)
	for key: String in keys:
		assert_ne(tr(key), key, key)


func test_default_font_has_french_glyphs() -> void:
	var label := Label.new()
	add_child_autofree(label)
	var font := label.get_theme_default_font()
	assert_eq(font.resource_path, FONT)
	for index: int in FRENCH_GLYPHS.length():
		assert_true(font.has_char(FRENCH_GLYPHS.unicode_at(index)), FRENCH_GLYPHS[index])


func test_ui_scale_follows_the_pixel_scale() -> void:
	var main := await _make_main()
	var view: PixelView = main.get_node("PixelView")
	var ui: CanvasLayer = main.get_node("UI")
	var hud: Control = main.get_node("UI/Hud")
	view.size = Vector2(1920, 1080)
	await wait_process_frames(1)
	assert_eq(ui.scale, Vector2(3, 3))
	assert_eq(hud.size, Vector2(640, 360))


func test_credits_toggle() -> void:
	var main := await _make_main()
	var credits: Control = main.get_node("UI/Hud/Credits")
	assert_false(credits.visible)
	_send_action("toggle_credits")
	await wait_process_frames(2)
	assert_true(credits.visible)
	_send_action("toggle_credits")
	await wait_process_frames(2)
	assert_false(credits.visible)


func test_credits_name_the_engine_and_the_font() -> void:
	var main := await _make_main()
	var text: RichTextLabel = main.get_node("UI/Hud/Credits/Margin/Text")
	assert_string_contains(text.text, "Godot Engine")
	assert_string_contains(text.text, "Tiny5")
	assert_string_contains(text.text, Engine.get_license_text().substr(0, 40))


func test_saving_shows_a_message() -> void:
	var main := await _make_main()
	var message: Label = main.get_node("UI/Hud/Message")
	assert_false(message.visible)
	EventBus.game_saved.emit(0)
	assert_true(message.visible)
	assert_eq(message.text, tr("HUD_SAVED"))
	await wait_seconds(DebugHud.MESSAGE_SECONDS + 0.2)
	assert_false(message.visible)


func test_status_shows_the_version() -> void:
	var main := await _make_main()
	var status: Label = main.get_node("UI/Hud/Status")
	await wait_seconds(DebugHud.STATUS_SECONDS + 0.1)
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_string_contains(status.text, version)


func _make_main() -> Main:
	var main: Main = SCENE.instantiate()
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


func _send_action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)


func _translation_keys() -> Array[String]:
	var keys: Array[String] = []
	var file := FileAccess.open(STRINGS, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if not row[0].is_empty():
			keys.append(row[0])
	return keys


func test_status_shows_whole_frames_per_second() -> void:
	var main := await _make_main()
	var status: Label = main.get_node("UI/Hud/Status")
	await wait_seconds(DebugHud.STATUS_SECONDS + 0.1)
	var pattern := RegEx.create_from_string("· \\d+ IPS$")
	assert_not_null(pattern.search(status.text), status.text)
