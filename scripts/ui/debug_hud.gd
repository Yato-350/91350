class_name DebugHud
extends Control
## Interface provisoire du prototype : aide des commandes, version et images par
## seconde, messages de sauvegarde, panneau des crédits.
## Elle est dessinée en pixels basse résolution ; Main l'agrandit à l'échelle entière.

const MESSAGE_SECONDS := 2.0
const STATUS_SECONDS := 0.5

var _status_age := STATUS_SECONDS
var _message_tween: Tween

@onready var _status: Label = $Status
@onready var _message: Label = $Message
@onready var _credits: Control = $Credits
@onready var _credits_text: RichTextLabel = $Credits/Margin/Text


func _ready() -> void:
	_message.hide()
	_credits.hide()
	_credits_text.text = (
		"%s\n\n%s\n\n%s" % [tr("CREDITS_TITLE"), tr("CREDITS_BODY"), Engine.get_license_text()]
	)
	EventBus.game_saved.connect(func(_slot: int) -> void: show_message("HUD_SAVED"))
	EventBus.game_loaded.connect(func(_slot: int) -> void: show_message("HUD_LOADED"))


func _process(delta: float) -> void:
	_status_age += delta
	if _status_age < STATUS_SECONDS:
		return
	_status_age = 0.0
	var version: String = ProjectSettings.get_setting("application/config/version")
	var values := {"version": version, "fps": roundi(Engine.get_frames_per_second())}
	_status.text = tr("HUD_STATUS").format(values)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_credits"):
		_credits.visible = not _credits.visible


## Affiche un court message traduit, puis le masque.
func show_message(key: String) -> void:
	_message.text = tr(key)
	_message.show()
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_callback(_message.hide).set_delay(MESSAGE_SECONDS)
