class_name Neighbourhood
extends RefCounted
## Le vocabulaire des fichiers de dialogue, côté quartier : l'heure et le couvre-feu, la
## réputation d'Akan, le Soutien et la Vigilance de la zone, le sommeil et les trajets
## (« if curfew() », « $> vigilance(1) »). Le récit lui-même est dans Story.


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


## Emmène Akan ailleurs à la fin de la réplique : travel("hall_tour@escalier").
func travel(target: String) -> void:
	EventBus.travel_requested.emit(target)
