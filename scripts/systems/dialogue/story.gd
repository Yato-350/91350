class_name Story
extends RefCounted
## Le vocabulaire des fichiers de dialogue, côté récit : ce qu'une réplique peut lire de
## l'histoire d'Akan (« if flag("radio") ») et ce qu'elle peut y changer
## (« $> give("piles", 2) »). Le quartier (heure, Soutien, Vigilance) est dans
## Neighbourhood. Les dialogues ne touchent ainsi jamais directement aux systèmes du jeu.


func flag(flag_name: String) -> bool:
	return GameState.has_flag(flag_name)


func set_flag(flag_name: String) -> void:
	GameState.set_flag(flag_name)


func clear_flag(flag_name: String) -> void:
	GameState.set_flag(flag_name, false)


func has(item: String, amount: int = 1) -> bool:
	return GameState.inventory.has(item, amount)


func give(item: String, amount: int = 1) -> void:
	GameState.give(item, amount)


## Range un objet du sac dans un raccourci (0 à 3), pour le tutoriel.
func shortcut(index: int, item: String) -> void:
	GameState.inventory.assign_quick_slot(index, item)


## Retire des objets du sac ; rend false (sans rien retirer) s'il en manque.
func take(item: String, amount: int = 1) -> bool:
	return GameState.inventory.remove(item, amount)


## Signale un événement aux quêtes : objective("TALK", "daronne").
func objective(type: String, target: String, amount: int = 1) -> void:
	GameState.objective(type, target, amount)


func start_quest(quest: String) -> void:
	GameState.quests.start(quest)


func quest_active(quest: String) -> bool:
	return GameState.quests.is_active(quest)


func quest_done(quest: String) -> bool:
	return GameState.quests.is_done(quest)


func step(quest: String, step_id: String) -> bool:
	return GameState.quests.is_step(quest, step_id)


func xp(amount: int) -> void:
	GameState.progression.add_xp(amount)
