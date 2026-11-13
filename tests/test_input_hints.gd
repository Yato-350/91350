extends GutTest


func after_each() -> void:
	InputHints.using_pad = false


func test_keyboard_hint_names_the_key() -> void:
	InputHints.using_pad = false
	assert_eq(InputHints.label(&"interact"), "[F]")
	assert_eq(InputHints.label(&"attack"), "[%s]" % tr("KEY_SPACE"))
	assert_eq(InputHints.label(&"run"), "[%s]" % tr("KEY_SHIFT"))


func test_pad_hint_names_the_button() -> void:
	InputHints.using_pad = true
	assert_eq(InputHints.label(&"interact"), "(A)")
	assert_eq(InputHints.label(&"pause"), "(Start)")
	assert_eq(InputHints.label(&"quick_save"), "", "pas de bouton pour cette action")


func test_the_last_device_used_decides() -> void:
	var button := InputEventJoypadButton.new()
	button.pressed = true
	InputHints.note_event(button)
	assert_true(InputHints.using_pad)
	var key := InputEventKey.new()
	key.pressed = true
	InputHints.note_event(key)
	assert_false(InputHints.using_pad)
	var drift := InputEventJoypadMotion.new()
	drift.axis_value = 0.1
	InputHints.note_event(drift)
	assert_false(InputHints.using_pad, "un stick qui dérive ne compte pas")
	var push := InputEventJoypadMotion.new()
	push.axis_value = -0.9
	InputHints.note_event(push)
	assert_true(InputHints.using_pad)


func test_unknown_action_has_no_hint() -> void:
	assert_eq(InputHints.label(&"licorne"), "")
