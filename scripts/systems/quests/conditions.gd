class_name Conditions
## Évalue une condition écrite dans les données (présence d'un personnage, prérequis d'une
## quête, porte fermée). Toutes les clés présentes doivent être vraies :
##
##   flags, not_flags                  drapeaux d'histoire posés / absents
##   quests_done, quests_active        quêtes terminées / en cours
##   quests_not_started                quêtes jamais commencées
##   step                              « quête:étape » en cours
##   items                             {objet: nombre} dans le sac
##   hours                             [de, à[ en heures, minuit compris (« [21, 6] »)
##   status_max                        statut citoyen au plus égal à cette valeur
##   reputation                        {groupe: minimum}

const STEP_SEPARATOR := ":"


static func check(condition: Dictionary) -> bool:
	var quests := GameState.quests
	for flag: String in condition.get("flags", []):
		if not GameState.has_flag(flag):
			return false
	for flag: String in condition.get("not_flags", []):
		if GameState.has_flag(flag):
			return false
	for quest: String in condition.get("quests_done", []):
		if not quests.is_done(quest):
			return false
	for quest: String in condition.get("quests_active", []):
		if not quests.is_active(quest):
			return false
	for quest: String in condition.get("quests_not_started", []):
		if quests.is_active(quest) or quests.is_done(quest):
			return false
	if condition.has("step"):
		var step: String = condition["step"]
		var quest := step.get_slice(STEP_SEPARATOR, 0)
		if not quests.is_step(quest, step.get_slice(STEP_SEPARATOR, 1)):
			return false
	var items: Dictionary = condition.get("items", {})
	for item: String in items:
		if not GameState.inventory.has(item, int(items[item])):
			return false
	if condition.has("hours") and not _in_hours(condition["hours"]):
		return false
	if (
		GameState.surveillance.status
		> int(condition.get("status_max", Surveillance.Status.ENNEMI_PUBLIC))
	):
		return false
	var reputation: Dictionary = condition.get("reputation", {})
	for group: String in reputation:
		if GameState.progression.reputation(group) < int(reputation[group]):
			return false
	return true


static func _in_hours(hours: Array) -> bool:
	var now := GameState.clock.hour()
	var from := int(hours[0])
	var to := int(hours[1])
	if from <= to:
		return now >= from and now < to
	return now >= from or now < to
