class_name PauseMenu
extends MenuScreen
## La pause : où l'on en est, et de quoi reprendre, sauvegarder, recharger ou s'arrêter.


func build() -> void:
	add_title("PAUSE_TITLE")
	var objective := GameState.quests.tracked_text()
	if not objective.is_empty():
		add_text("▸ %s" % tr(objective))
	add_button("resume", "PAUSE_RESUME")
	add_button("save", "PAUSE_SAVE")
	add_button("load", "PAUSE_LOAD", SaveManager.has_save())
	add_button("title", "PAUSE_TITLE_SCREEN")
	if not OS.has_feature("web"):
		add_button("quit", "MENU_QUIT")
