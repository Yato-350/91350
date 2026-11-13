extends Node
## L'état d'une partie : les systèmes de jeu (logique pure) et les drapeaux d'histoire.
##
## Autoload sauvegardable. Il relaie les signaux des systèmes sur l'EventBus, pour que
## l'interface et le monde n'aient pas à connaître les systèmes eux-mêmes.

## Un lieu décrit par les données s'écrit « zone:<identifiant>[@repère] ».
const ZONE_PREFIX := "zone:"
const MARKER_SEPARATOR := "@"
## Le haut-parleur prévient tant de minutes avant le couvre-feu.
const CURFEW_WARNING_MINUTES := 10.0
## À partir de cette Vigilance, le régime avance le couvre-feu d'une heure.
const CURFEW_ADVANCE_VIGILANCE := 3
## Après un acte interdit (tag, sabotage, coup), Akan reste suspect ce temps-là (s).
const OFFENCE_MEMORY_SECONDS := 6.0
const MSEC_PER_SECOND := 1000.0
## La quête qui ouvre une nouvelle partie.
const FIRST_QUEST := "ascenseur_en_panne"
## Objectifs « USE » génériques : ce qu'un objet fait, quel qu'il soit.
const USE_DRINK := "boire"
const USE_EAT := "manger"

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

var _curfew := false
var _offence_until := -1.0


func _ready() -> void:
	add_to_group(SaveManager.SAVEABLE_GROUP)
	new_game()


func _process(delta: float) -> void:
	if playing:
		advance_time(delta)


## Avance l'heure de `seconds` secondes réelles et annonce le couvre-feu.
func advance_time(seconds: float) -> void:
	var before := clock.minutes
	clock.advance(seconds)
	var warning := (GameClock.CURFEW_START_HOUR - _curfew_advance()) * GameClock.MINUTES_PER_HOUR
	if _crossed(before, clock.minutes, warning - CURFEW_WARNING_MINUTES):
		EventBus.notified.emit("CURFEW_WARNING")
	var now := is_curfew()
	if now != _curfew:
		_curfew = now
		EventBus.curfew_changed.emit(now)
		EventBus.notified.emit("CURFEW_START" if now else "CURFEW_END")


## Akan vient de faire quelque chose d'interdit : les guetteurs qui le voient s'en
## inquiètent pendant OFFENCE_MEMORY_SECONDS.
func commit_offence(seconds: float = OFFENCE_MEMORY_SECONDS) -> void:
	_offence_until = Time.get_ticks_msec() + seconds * MSEC_PER_SECOND


## Vrai si un guetteur qui voit Akan a de quoi s'inquiéter : un acte interdit récent,
## dehors pendant le couvre-feu, ou un statut d'ennemi public.
func is_offending() -> bool:
	if Time.get_ticks_msec() < _offence_until:
		return true
	if surveillance.status == Surveillance.Status.ENNEMI_PUBLIC:
		return true
	return is_curfew() and is_outdoors()


## Vrai dehors (dans une zone), faux dans un intérieur.
func is_outdoors() -> bool:
	return not DataRegistry.entry("zones", place_id()).is_empty()


## Vrai pendant le couvre-feu (avancé d'une heure quand la Vigilance est haute).
func is_curfew() -> bool:
	return clock.is_curfew(_curfew_advance())


func _curfew_advance() -> int:
	var high := surveillance.level(territory_id) >= CURFEW_ADVANCE_VIGILANCE
	return 1 if high and not territory_id.is_empty() else 0


# L'heure `mark` (en minutes) a-t-elle été passée en allant de `before` à `after` ?
static func _crossed(before: float, after: float, mark: float) -> bool:
	if after >= before:
		return before < mark and mark <= after
	return mark > before or mark <= after


func new_game() -> void:
	_create_systems()
	flags = {}
	location = ""
	saved_position = []
	territory_id = ""
	_curfew = is_curfew()
	_offence_until = -1.0
	EventBus.game_state_reset.emit()


## La quête dont on suit l'objectif : la dernière lancée parmi celles en cours.
func tracked_quest() -> String:
	var active := quests.active_ids()
	return active[active.size() - 1] if not active.is_empty() else ""


## Le texte (clé de traduction) de l'objectif en cours de la quête suivie, ou "".
func tracked_objective() -> String:
	var quest := tracked_quest()
	return quests.current_step(quest).get("text", "") if not quest.is_empty() else ""


## Akan entre dans un lieu ; `territory` est la zone de territoire qui l'abrite.
func enter(new_location: String, territory: String) -> void:
	location = new_location
	territory_id = territory
	EventBus.location_changed.emit()
	if not place_id().is_empty():
		objective("GOTO", place_id())


## Identifiant du lieu courant (« hall_tour », « grigny2 »), ou "" pour une scène d'essai.
func place_id() -> String:
	if not location.begins_with(ZONE_PREFIX):
		return ""
	return location.trim_prefix(ZONE_PREFIX).get_slice(MARKER_SEPARATOR, 0)


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


## Vrai si Akan porte un objet lourd (bidon plein…) : il ne peut plus courir.
func carries_heavy_load() -> bool:
	for slot: Dictionary in inventory.slots:
		if DataRegistry.entry("items", slot.get("id", "")).get("heavy", false):
			return true
	return false


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
	if effects.get("thirst", 0.0) > 0.0:
		objective("USE", USE_DRINK)
	if effects.get("hunger", 0.0) > 0.0:
		objective("USE", USE_EAT)
	objective("USE", item_id)
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
	_curfew = is_curfew()
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
	inventory.changed.connect(func(_item: String) -> void: _check_collect())
	connect_quests()
	territory.changed.connect(EventBus.territory_changed.emit)
	territory.liberated.connect(EventBus.zone_liberated.emit)
	surveillance.vigilance_changed.connect(EventBus.vigilance_changed.emit)
	surveillance.status_changed.connect(EventBus.status_changed.emit)
	progression.leveled_up.connect(EventBus.leveled_up.emit)


## Relie le journal de quêtes au reste du jeu (à refaire si on le remplace).
func connect_quests() -> void:
	quests.quest_started.connect(EventBus.quest_started.emit)
	quests.progressed.connect(EventBus.quest_progressed.emit)
	quests.progressed.connect(func(_quest: String) -> void: _check_collect())
	quests.step_completed.connect(_on_step_completed)
	quests.quest_completed.connect(_on_quest_completed)


# Un objectif « COLLECT » est atteint dès que le sac contient ce qu'il faut, même si
# l'objet y était déjà avant l'étape.
func _check_collect() -> void:
	for quest_id: String in quests.active_ids():
		var step := quests.current_step(quest_id)
		if step.get("type") != "COLLECT":
			continue
		var target: String = step.get("target", "")
		var missing := int(step.get("count", 1)) - quests.progress(quest_id)
		if missing > 0 and inventory.count(target) >= int(step.get("count", 1)):
			quests.notify("COLLECT", target, missing)


func _on_step_completed(quest_id: String, step_id: String) -> void:
	var quest := _quest_definition(quest_id)
	for step: Dictionary in quest.get("steps", []):
		if step.get("id") != step_id:
			continue
		apply_effects(step.get("effects", {}), quest.get("zone", territory_id))
		var scene: Array = step.get("dialogue", [])
		if scene.size() == 2:
			EventBus.dialogue_requested.emit(scene[0], scene[1])
	EventBus.quest_step_completed.emit(quest_id, step_id)


# La fiche d'une quête : celle des données, ou celle qu'utilise le journal (tests).
func _quest_definition(quest_id: String) -> Dictionary:
	var quest := DataRegistry.entry("quests", quest_id)
	return quest if not quest.is_empty() else quests.definition(quest_id)


func _on_quest_completed(quest_id: String) -> void:
	var quest := _quest_definition(quest_id)
	apply_effects(quest.get("rewards", {}), quest.get("zone", territory_id))
	EventBus.quest_completed.emit(quest_id)


func _read_position(raw: Array) -> Array:
	if raw.size() != 3:
		return []
	for value: Variant in raw:
		if not (value is float or value is int):
			return []
	return raw.duplicate()
