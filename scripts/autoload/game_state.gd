extends Node
## L'état d'une partie : les systèmes de jeu (logique pure) et les drapeaux d'histoire.
##
## Autoload sauvegardable. Il relaie les signaux des systèmes sur l'EventBus, pour que
## l'interface et le monde n'aient pas à connaître les systèmes eux-mêmes.

var save_id: StringName = &"game"

var clock: GameClock
var vitals: Vitals
var needs: Needs
var inventory: Inventory
var quests: QuestLog
var territory: Territory
var surveillance: Surveillance
var progression: Progression
## Drapeaux d'histoire : nom → valeur (vrai, ou un compteur).
var flags := {}
## Lieu où se trouve Akan, tel que Main le charge (« zone:grigny2@gare »).
var location := ""
## Position d'Akan dans ce lieu au moment de la sauvegarde : [x, y, z], ou [] si inconnue.
var saved_position: Array = []
## Zone de territoire du lieu courant : c'est là que portent Soutien et Vigilance.
var territory_id := ""
## Le temps ne passe que pendant le jeu, pas dans les menus.
var playing := false


func _ready() -> void:
	add_to_group(SaveManager.SAVEABLE_GROUP)
	new_game()


func _process(delta: float) -> void:
	if playing:
		clock.advance(delta)


func new_game() -> void:
	_create_systems()
	flags = {}
	location = ""
	saved_position = []
	territory_id = ""
	EventBus.game_state_reset.emit()


## Avance le corps d'Akan : endurance, faim, soif, et ce qu'elles coûtent à la santé.
func tick_body(delta: float, running: bool) -> void:
	vitals.tick(delta, running, needs.is_depleted())
	vitals.damage(needs.tick(delta, running))


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func set_flag(flag: String, value: bool = true) -> void:
	if value:
		flags[flag] = true
	else:
		flags.erase(flag)
	EventBus.flag_changed.emit(flag)


## Donne des objets à Akan ; ce qui ne tient pas dans le sac tombe à ses pieds.
func give(item_id: String, amount: int = 1) -> void:
	var left := inventory.add(item_id, amount)
	if left > 0:
		EventBus.item_dropped.emit(item_id, left)


## Consomme ou enfile un objet du sac. Rend false s'il n'y en a pas ou s'il ne sert à rien.
func use_item(item_id: String) -> bool:
	var item := DataRegistry.entry("items", item_id)
	var effects: Dictionary = item.get("use", {})
	var bag: String = item.get("bag", "")
	if not inventory.has(item_id) or (effects.is_empty() and bag.is_empty()):
		return false
	if not bag.is_empty() and not inventory.set_bag(bag):
		return false
	inventory.remove(item_id)
	needs.drink(effects.get("thirst", 0.0))
	needs.eat(effects.get("hunger", 0.0))
	vitals.heal(effects.get("health", 0.0))
	EventBus.item_used.emit(item_id)
	return true


## Signale un événement de jeu aux quêtes (« TALK », « daronne »).
func objective(type: String, target: String, amount: int = 1) -> void:
	quests.notify(type, target, amount)


## Applique des effets décrits en données : récompenses de quête, choix de dialogue.
func apply_effects(effects: Dictionary, zone_id: String = territory_id) -> void:
	progression.add_xp(int(effects.get("xp", 0)))
	progression.skill_points += int(effects.get("skill_points", 0))
	var given: Dictionary = effects.get("items", {})
	for item_id: String in given:
		give(item_id, int(given[item_id]))
	var taken: Dictionary = effects.get("take", {})
	for item_id: String in taken:
		inventory.remove(item_id, int(taken[item_id]))
	var reputation: Dictionary = effects.get("reputation", {})
	for group: String in reputation:
		progression.add_reputation(group, int(reputation[group]))
	territory.add_support(zone_id, int(effects.get("support", 0)))
	territory.add_control(zone_id, int(effects.get("control", 0)))
	if effects.has("vigilance"):
		surveillance.report(zone_id, effects["vigilance"])
	for flag: String in effects.get("flags", []):
		set_flag(flag)
	for quest_id: String in effects.get("start", []):
		quests.start(quest_id)
	if effects.get("liberate", false):
		territory.liberate(zone_id)


func save_state() -> Dictionary:
	return {
		"clock": clock.to_dict(),
		"vitals": vitals.to_dict(),
		"needs": needs.to_dict(),
		"inventory": inventory.to_dict(),
		"quests": quests.to_dict(),
		"territory": territory.to_dict(),
		"surveillance": surveillance.to_dict(),
		"progression": progression.to_dict(),
		"flags": flags.duplicate(),
		"location": location,
		"position": saved_position.duplicate(),
	}


## Repart d'une partie neuve : ce qui manque dans la sauvegarde garde sa valeur de départ.
func load_state(state: Dictionary) -> void:
	_create_systems()
	clock.from_dict(SaveCodec.table(state, "clock"))
	vitals.from_dict(SaveCodec.table(state, "vitals"))
	needs.from_dict(SaveCodec.table(state, "needs"))
	inventory.from_dict(SaveCodec.table(state, "inventory"))
	quests.from_dict(SaveCodec.table(state, "quests"))
	territory.from_dict(SaveCodec.table(state, "territory"))
	surveillance.from_dict(SaveCodec.table(state, "surveillance"))
	progression.from_dict(SaveCodec.table(state, "progression"))
	flags = SaveCodec.table(state, "flags").duplicate()
	location = SaveCodec.text(state, "location", "")
	saved_position = _read_position(SaveCodec.list(state, "position"))
	EventBus.game_state_reset.emit()


func _create_systems() -> void:
	clock = GameClock.new()
	vitals = Vitals.new()
	needs = Needs.new()
	inventory = Inventory.new(DataRegistry.all("items"))
	quests = QuestLog.new(DataRegistry.all("quests"))
	territory = Territory.new()
	surveillance = Surveillance.new()
	progression = Progression.new()
	var zones := DataRegistry.all("zones")
	for zone_id: String in zones:
		var zone: Dictionary = zones[zone_id]
		territory.register(zone_id, int(zone.get("control", 0)), int(zone.get("support", 0)))
	vitals.downed.connect(EventBus.player_downed.emit)
	inventory.changed.connect(EventBus.inventory_changed.emit)
	quests.quest_started.connect(EventBus.quest_started.emit)
	quests.progressed.connect(EventBus.quest_progressed.emit)
	quests.step_completed.connect(_on_step_completed)
	quests.quest_completed.connect(_on_quest_completed)
	territory.changed.connect(EventBus.territory_changed.emit)
	territory.liberated.connect(EventBus.zone_liberated.emit)
	surveillance.vigilance_changed.connect(EventBus.vigilance_changed.emit)
	surveillance.status_changed.connect(EventBus.status_changed.emit)
	progression.leveled_up.connect(EventBus.leveled_up.emit)


func _on_step_completed(quest_id: String, step_id: String) -> void:
	var quest := DataRegistry.entry("quests", quest_id)
	for step: Dictionary in quest.get("steps", []):
		if step.get("id") == step_id:
			apply_effects(step.get("effects", {}), quest.get("zone", territory_id))
	EventBus.quest_step_completed.emit(quest_id, step_id)


func _on_quest_completed(quest_id: String) -> void:
	var quest := DataRegistry.entry("quests", quest_id)
	apply_effects(quest.get("rewards", {}), quest.get("zone", territory_id))
	EventBus.quest_completed.emit(quest_id)


func _read_position(raw: Array) -> Array:
	if raw.size() != 3:
		return []
	for value: Variant in raw:
		if not (value is float or value is int):
			return []
	return raw.duplicate()
