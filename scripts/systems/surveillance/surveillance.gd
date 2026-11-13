class_name Surveillance
extends RefCounted
## Vigilance du régime par zone (0 à 5) et statut citoyen d'Akan.

signal vigilance_changed(zone_id: String, level: int)
signal status_changed(status: Status)

enum Status { CONFORME, SURVEILLE, FICHE, ENNEMI_PUBLIC }

const MAX_LEVEL := 5
## Secondes passées caché pour que la Vigilance redescende d'un cran.
const DECAY_SECONDS := 45.0
## Vigilance à partir de laquelle le statut citoyen se dégrade.
const STATUS_LEVELS := {
	3: Status.SURVEILLE,
	4: Status.FICHE,
	5: Status.ENNEMI_PUBLIC,
}

var status := Status.CONFORME

## zone → chaleur (flottant de 0 à MAX_LEVEL ; la Vigilance en est la partie entière).
var _heat := {}
## zone → secondes passées caché depuis la dernière baisse.
var _hidden_seconds := {}


func level(zone_id: String) -> int:
	return floori(_heat.get(zone_id, 0.0))


## Un capteur a vu Akan agir : la Vigilance de la zone monte de `amount`.
func report(zone_id: String, amount: float) -> void:
	_set_heat(zone_id, _heat.get(zone_id, 0.0) + amount)
	_hidden_seconds[zone_id] = 0.0
	for threshold: int in STATUS_LEVELS:
		var reached: Status = STATUS_LEVELS[threshold]
		if level(zone_id) >= threshold and reached > status:
			status = reached
			status_changed.emit(status)


## Avance le temps dans la zone où se trouve Akan ; `hidden` : aucun capteur ne le voit.
func tick(zone_id: String, delta: float, hidden: bool) -> void:
	if not hidden or level(zone_id) == 0:
		return
	var seconds: float = _hidden_seconds.get(zone_id, 0.0) + delta
	while seconds >= DECAY_SECONDS:
		seconds -= DECAY_SECONDS
		_set_heat(zone_id, _heat.get(zone_id, 0.0) - 1.0)
	_hidden_seconds[zone_id] = seconds


## Un cran de plus (arrestation…), jusqu'à ennemi public.
func raise_status() -> void:
	if status == Status.ENNEMI_PUBLIC:
		return
	status = (status + 1) as Status
	status_changed.emit(status)


## Ramène la Vigilance de la zone à `value` (au plus).
func calm(zone_id: String, value: int) -> void:
	if level(zone_id) > value:
		_set_heat(zone_id, value)


## Le statut ne redescend jamais seul : il faut de faux papiers ou changer de tête.
func lower_status() -> void:
	if status == Status.CONFORME:
		return
	status = (status - 1) as Status
	status_changed.emit(status)


func to_dict() -> Dictionary:
	return {"status": status, "heat": _heat.duplicate()}


func from_dict(state: Dictionary) -> void:
	var saved_status := int(SaveCodec.number(state, "status", status))
	status = clampi(saved_status, Status.CONFORME, Status.ENNEMI_PUBLIC) as Status
	_heat.clear()
	_hidden_seconds.clear()
	var saved_heat := SaveCodec.table(state, "heat")
	for zone_id: Variant in saved_heat:
		if zone_id is String:
			_set_heat(zone_id, SaveCodec.number(saved_heat, zone_id, 0.0))
	status_changed.emit(status)


func _set_heat(zone_id: String, value: float) -> void:
	var before := level(zone_id)
	_heat[zone_id] = clampf(value, 0.0, MAX_LEVEL)
	if level(zone_id) != before:
		vigilance_changed.emit(zone_id, level(zone_id))
