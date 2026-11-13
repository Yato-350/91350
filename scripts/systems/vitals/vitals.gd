class_name Vitals
extends RefCounted
## Santé et endurance d'un personnage. Logique pure : on l'avance avec tick().

signal downed

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
## Endurance perdue par seconde de course.
const RUN_COST := 10.0
## Endurance regagnée par seconde, après REGEN_DELAY secondes sans courir.
const REGEN := 15.0
const REGEN_DELAY := 1.0
## Corps affaibli (faim ou soif à zéro) : l'endurance remonte deux fois moins vite.
const WEAK_REGEN_FACTOR := 0.5
## Après un essoufflement complet, il faut remonter jusque-là avant de recourir.
const RECOVERY_THRESHOLD := 25.0

var health := MAX_HEALTH
var stamina := MAX_STAMINA

var _rest_seconds := 0.0
var _exhausted := false


func can_run() -> bool:
	return not _exhausted and stamina > 0.0


func is_down() -> bool:
	return health <= 0.0


## Avance de `delta` secondes, pendant lesquelles le personnage court (`running`) ou non.
func tick(delta: float, running: bool, weakened: bool) -> void:
	if running and can_run():
		stamina = maxf(stamina - RUN_COST * delta, 0.0)
		_rest_seconds = 0.0
		_exhausted = stamina <= 0.0
		return
	# Seul le temps de repos passé au-delà du délai fait remonter l'endurance.
	var regen_seconds := clampf(_rest_seconds + delta - REGEN_DELAY, 0.0, delta)
	_rest_seconds += delta
	var rate := REGEN * (WEAK_REGEN_FACTOR if weakened else 1.0)
	stamina = minf(stamina + rate * regen_seconds, MAX_STAMINA)
	if stamina >= RECOVERY_THRESHOLD:
		_exhausted = false


func damage(amount: float) -> void:
	if is_down() or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if is_down():
		downed.emit()


## Soigne (même à terre : c'est ainsi qu'on se relève).
func heal(amount: float) -> void:
	health = minf(health + maxf(amount, 0.0), MAX_HEALTH)


func to_dict() -> Dictionary:
	return {"health": health, "stamina": stamina}


func from_dict(state: Dictionary) -> void:
	health = clampf(SaveCodec.number(state, "health", health), 0.0, MAX_HEALTH)
	stamina = clampf(SaveCodec.number(state, "stamina", stamina), 0.0, MAX_STAMINA)
	_exhausted = stamina <= 0.0
	_rest_seconds = 0.0
