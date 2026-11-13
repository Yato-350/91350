class_name Neighbourhood
extends RefCounted
## Le vocabulaire des fichiers de dialogue, côté quartier : l'heure et le couvre-feu, la
## réputation d'Akan, le Soutien et la Vigilance de la zone, le sommeil et les trajets
## (« if curfew() », « $> vigilance(1) »). Le récit lui-même est dans Story.

## Source du signalement quand un dialogue donne l'alerte.
const ALARM_SOURCE := "alarme"


func reputation(group: String) -> int:
	return GameState.progression.reputation(group)


func rep(group: String, amount: int) -> void:
	GameState.progression.add_reputation(group, amount)


func support(amount: int) -> void:
	GameState.territory.add_support(GameState.territory_id, amount)


func vigilance(amount: float) -> void:
	GameState.surveillance.report(GameState.territory_id, amount)


func hour() -> int:
	return GameState.clock.hour()


## Vrai pendant le couvre-feu, avancé d'une heure quand le régime s'inquiète.
func curfew() -> bool:
	return GameState.is_curfew()


## Akan dort jusqu'à la prochaine fois qu'il est `wake_hour` heures : le temps passe
## (couvre-feu compris) et la nuit répare le corps ; le ventre, lui, attend le réveil.
func sleep_until(wake_hour: int) -> void:
	var minutes := GameState.clock.minutes_until(wake_hour)
	GameState.advance_time(minutes / GameClock.MINUTES_PER_SECOND)
	GameState.vitals.heal(Vitals.MAX_HEALTH)


## Vrai si Akan vient d'être repéré : mieux vaut se faire oublier un moment.
func hot() -> bool:
	return GameState.surveillance.is_hot(Time.get_ticks_msec() / GameState.MSEC_PER_SECOND)


## Donne l'alerte autour d'Akan (un tag découvert, un cri) : il devient suspect et les
## Vigiles du coin accourent là où il se tient.
func alarm() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player := tree.get_first_node_in_group(Player.GROUP) as Player
	if player == null:
		return
	GameState.commit_offence()
	EventBus.sound_requested.emit(&"alarme")
	EventBus.player_spotted.emit(player.global_position, ALARM_SOURCE)


## Un bruitage au fil de la scène : sound("bombe"), sound("coupe").
func sound(sound_name: String) -> void:
	EventBus.sound_requested.emit(StringName(sound_name))


## Emmène Akan ailleurs à la fin de la réplique : travel("hall_tour@escalier").
func travel(target: String) -> void:
	EventBus.travel_requested.emit(target)
