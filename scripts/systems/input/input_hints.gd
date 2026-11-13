class_name InputHints
## Nomme la touche ou le bouton d'une action, selon le dernier périphérique utilisé :
## « [F] » au clavier, « (A) » à la manette. La touche affichée suit la disposition du
## clavier du joueur (sur un AZERTY, « avancer » s'affiche [Z]).

const PAD_BUTTONS := {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
}
## Touches dont le nom se traduit.
const NAMED_KEYS := {
	KEY_SPACE: "KEY_SPACE",
	KEY_SHIFT: "KEY_SHIFT",
	KEY_ESCAPE: "KEY_ESCAPE",
	KEY_TAB: "KEY_TAB",
	KEY_CTRL: "KEY_CTRL",
}
## Serveurs d'affichage qui savent traduire une touche physique selon la disposition.
const LAYOUT_AWARE_DISPLAYS: Array[String] = ["Windows", "macOS", "X11", "Wayland"]
## En dessous, un stick ne fait que dériver : ce n'est pas un geste du joueur.
const STICK_THRESHOLD := 0.5

static var using_pad := false


## À appeler pour chaque entrée : retient si le joueur tient un clavier ou une manette.
static func note_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		using_pad = true
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) >= STICK_THRESHOLD:
			using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


## « [F] » ou « (A) » pour l'action ; "" si elle n'a rien sur le périphérique en main.
static func label(action: StringName) -> String:
	if not InputMap.has_action(action):
		return ""
	for event: InputEvent in InputMap.action_get_events(action):
		var button := event as InputEventJoypadButton
		if using_pad and button != null and PAD_BUTTONS.has(button.button_index):
			return "(%s)" % PAD_BUTTONS[button.button_index]
		var key := event as InputEventKey
		if not using_pad and key != null:
			return "[%s]" % _key_name(key.physical_keycode)
	return ""


static func _key_name(physical_keycode: Key) -> String:
	if NAMED_KEYS.has(physical_keycode):
		return TranslationServer.translate(NAMED_KEYS[physical_keycode])
	# Seuls les bureaux savent lire la disposition du clavier ; ailleurs (navigateur,
	# tests sans affichage), on nomme la touche d'après sa position sur un QWERTY.
	var keycode := physical_keycode
	if DisplayServer.get_name() in LAYOUT_AWARE_DISPLAYS:
		keycode = DisplayServer.keyboard_get_keycode_from_physical(physical_keycode)
	return OS.get_keycode_string(keycode)
