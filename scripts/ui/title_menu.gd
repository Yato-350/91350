class_name TitleMenu
extends MenuScreen
## L'écran titre, devant la tour d'Akan la nuit : nouvelle partie, continuer, crédits,
## quitter ; et l'attribution d'OpenStreetMap, due dès le démarrage.

const LOGO := "91350"
const LOGO_SIZE := 32
const LOGO_COLOR := "orange_sodium"


func _init() -> void:
	super()
	cancellable = false


func build() -> void:
	var logo := add_text(LOGO)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override(&"font_size", LOGO_SIZE)
	logo.add_theme_color_override(&"font_color", Palette.load_colors()[LOGO_COLOR])
	add_title("TITLE_SUBTITLE")
	add_button("new_game", "TITLE_NEW_GAME")
	add_button("continue", "TITLE_CONTINUE", SaveManager.has_save())
	add_button("credits", "TITLE_CREDITS")
	if not OS.has_feature("web"):
		add_button("quit", "MENU_QUIT")
	add_text(tr("ATTRIBUTION_OSM"))
	var version: String = ProjectSettings.get_setting("application/config/version")
	add_text("v%s" % version).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
