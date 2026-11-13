class_name GameClock
extends RefCounted
## L'heure du jeu : une journée dure 24 minutes réelles.

const MINUTES_PER_DAY := 1440.0
const MINUTES_PER_HOUR := 60.0
## Minutes de jeu écoulées par seconde réelle.
const MINUTES_PER_SECOND := 1.0
## Une partie commence le matin du premier jour.
const START_HOUR := 8.0
const DAWN_HOUR := 6.5
const DUSK_HOUR := 20.0
## Durée de l'aube et du crépuscule, centrés sur DAWN_HOUR et DUSK_HOUR.
const TWILIGHT_HOURS := 1.5
const CURFEW_START_HOUR := 21
const CURFEW_END_HOUR := 6

var day := 1
## Minutes écoulées depuis minuit.
var minutes := START_HOUR * MINUTES_PER_HOUR


## Avance de `seconds` secondes réelles.
func advance(seconds: float) -> void:
	minutes += seconds * MINUTES_PER_SECOND
	while minutes >= MINUTES_PER_DAY:
		minutes -= MINUTES_PER_DAY
		day += 1


func hour() -> int:
	return int(minutes / MINUTES_PER_HOUR)


## Minutes de jeu avant la prochaine fois qu'il sera `target_hour` heures (0 s'il l'est).
func minutes_until(target_hour: float) -> float:
	return fposmod(target_hour * MINUTES_PER_HOUR - minutes, MINUTES_PER_DAY)


func format() -> String:
	return "%02d:%02d" % [hour(), int(minutes) % int(MINUTES_PER_HOUR)]


## 0.0 en plein jour, 1.0 en pleine nuit, entre les deux à l'aube et au crépuscule.
func night_factor() -> float:
	var now := minutes / MINUTES_PER_HOUR
	var half := TWILIGHT_HOURS * 0.5
	var risen := smoothstep(DAWN_HOUR - half, DAWN_HOUR + half, now)
	var fallen := smoothstep(DUSK_HOUR - half, DUSK_HOUR + half, now)
	return 1.0 - risen + fallen


## Le couvre-feu court de 21 h à 6 h ; le régime l'avance de `advance_hours` s'il s'inquiète.
func is_curfew(advance_hours: int = 0) -> bool:
	var now := hour()
	return now >= CURFEW_START_HOUR - advance_hours or now < CURFEW_END_HOUR


func to_dict() -> Dictionary:
	return {"day": day, "minutes": minutes}


func from_dict(state: Dictionary) -> void:
	day = maxi(int(SaveCodec.number(state, "day", day)), 1)
	minutes = clampf(SaveCodec.number(state, "minutes", minutes), 0.0, MINUTES_PER_DAY - 1.0)
