class_name Needs
extends RefCounted
## Faim et soif, de 0 (à sec) à 100 (rassasié). Une pression, pas une punition.

const MAX := 100.0
const THIRST_PER_MINUTE := 4.0
const HUNGER_PER_MINUTE := 2.5
## Courir donne soif : la soif descend RUN_FACTOR fois plus vite.
const RUN_FACTOR := 2.0
## Temps passé à zéro avant que la santé ne commence à baisser.
const GRACE_SECONDS := 60.0
## Ensuite, la santé perd DAMAGE_PER_INTERVAL toutes les DAMAGE_INTERVAL secondes.
const DAMAGE_INTERVAL := 5.0
const DAMAGE_PER_INTERVAL := 1.0
const SECONDS_PER_MINUTE := 60.0

var thirst := MAX
var hunger := MAX

var _depleted_seconds := 0.0


## Vrai quand la faim ou la soif est à zéro : le corps est affaibli.
func is_depleted() -> bool:
	return thirst <= 0.0 or hunger <= 0.0


## Avance de `delta` secondes et rend les dégâts à infliger à la santé.
func tick(delta: float, running: bool) -> float:
	var thirst_rate := THIRST_PER_MINUTE * (RUN_FACTOR if running else 1.0)
	thirst = maxf(thirst - thirst_rate * delta / SECONDS_PER_MINUTE, 0.0)
	hunger = maxf(hunger - HUNGER_PER_MINUTE * delta / SECONDS_PER_MINUTE, 0.0)
	if not is_depleted():
		_depleted_seconds = 0.0
		return 0.0
	var before := _damage_steps(_depleted_seconds)
	_depleted_seconds += delta
	return (_damage_steps(_depleted_seconds) - before) * DAMAGE_PER_INTERVAL


func drink(amount: float) -> void:
	thirst = clampf(thirst + amount, 0.0, MAX)


func eat(amount: float) -> void:
	hunger = clampf(hunger + amount, 0.0, MAX)


func to_dict() -> Dictionary:
	return {"thirst": thirst, "hunger": hunger}


func from_dict(state: Dictionary) -> void:
	thirst = clampf(SaveCodec.number(state, "thirst", thirst), 0.0, MAX)
	hunger = clampf(SaveCodec.number(state, "hunger", hunger), 0.0, MAX)
	_depleted_seconds = 0.0


func _damage_steps(seconds: float) -> int:
	return maxi(floori((seconds - GRACE_SECONDS) / DAMAGE_INTERVAL), 0)
