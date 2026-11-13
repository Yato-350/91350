class_name ActEndScreen
extends MenuScreen
## La fin de l'acte 1 : Grigny 2 est libre. Le bilan des choix d'Akan, puis on continue
## d'explorer le quartier libéré ou l'on revient au titre.

const ZONE := "grigny2"
## Drapeau posé par un choix → ligne du bilan, dans l'ordre où on les lit.
const CHOICES: Array[Dictionary] = [
	{
		"tag_colere": "ACT1_TAG_COLERE",
		"tag_espoir": "ACT1_TAG_ESPOIR",
		"tag_humour": "ACT1_TAG_HUMOUR",
	},
	{
		"bernard_double": "ACT1_BERNARD_DOUBLE",
		"bernard_denonce": "ACT1_BERNARD_DENONCE",
		"bernard_parti": "ACT1_BERNARD_PARTI",
	},
	{
		"contact_rendu": "ACT1_CONTACT_RENDU",
		"contact_livre": "ACT1_CONTACT_LIVRE",
		"contact_paye": "ACT1_CONTACT_PAYE",
	},
]


func build() -> void:
	add_title("ACT1_END_TITLE")
	add_text(tr("ACT1_END_FREED"))
	for choice: Dictionary in CHOICES:
		for flag: String in choice:
			if GameState.has_flag(flag):
				add_text("· %s" % tr(choice[flag]))
	var support := GameState.territory.support(ZONE)
	add_text(tr("ACT1_SUPPORT").format({"value": support}))
	add_text(tr("ACT1_DAYS").format({"days": GameState.clock.day}))
	add_text(tr("ACT1_NEXT"))
	add_button("explore", "ACT1_EXPLORE")
	add_button("title", "PAUSE_TITLE_SCREEN")
