class_name CreditsScreen
extends MenuScreen
## Les crédits : toutes les attributions (OpenStreetMap, moteur, extensions, police, sons).

const TEXT_SIZE := Vector2(360, 200)


## Le texte complet des crédits, partagé avec le panneau F1 du HUD.
static func full_text() -> String:
	var title := String(TranslationServer.translate("CREDITS_TITLE"))
	var body := String(TranslationServer.translate("CREDITS_BODY"))
	return "%s\n\n%s\n\n%s" % [title, body, Engine.get_license_text()]


func _init() -> void:
	super()
	custom_minimum_size.x = TEXT_SIZE.x + SPACING * 4


func build() -> void:
	var text := RichTextLabel.new()
	text.name = "Text"
	text.text = full_text()
	text.custom_minimum_size = TEXT_SIZE
	text.scroll_active = true
	text.focus_mode = Control.FOCUS_ALL
	add_control(text)
	add_button(BACK, "MENU_BACK")
