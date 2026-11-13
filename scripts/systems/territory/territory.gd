class_name Territory
extends RefCounted
## Par zone : Contrôle du régime et Soutien populaire (0–100), et zones libérées.

signal changed(zone_id: String)
signal liberated(zone_id: String)

const MAX_VALUE := 100
## Une zone se libère quand le Contrôle est tombé et que le Soutien a monté.
const LIBERATION_MAX_CONTROL := 25
const LIBERATION_MIN_SUPPORT := 75
## Saturation du rendu dans une zone tenue par le régime : le gris, sans tout éteindre
## (les couleurs de la vie du quartier percent encore). Libre : pleine couleur.
const REGIME_SATURATION := 0.6
const FREE_SATURATION := 1.0

## zone → {"control": int, "support": int, "liberated": bool}
var _zones := {}


## Déclare une zone avec ses valeurs de départ ; sans effet si elle est déjà connue.
func register(zone_id: String, start_control: int, start_support: int) -> void:
	if _zones.has(zone_id):
		return
	_zones[zone_id] = {
		"control": clampi(start_control, 0, MAX_VALUE),
		"support": clampi(start_support, 0, MAX_VALUE),
		"liberated": false,
	}


func control(zone_id: String) -> int:
	return _value(zone_id, "control")


func support(zone_id: String) -> int:
	return _value(zone_id, "support")


func add_control(zone_id: String, amount: int) -> void:
	_add(zone_id, "control", amount)


func add_support(zone_id: String, amount: int) -> void:
	_add(zone_id, "support", amount)


func can_liberate(zone_id: String) -> bool:
	return (
		_zones.has(zone_id)
		and not is_liberated(zone_id)
		and control(zone_id) <= LIBERATION_MAX_CONTROL
		and support(zone_id) >= LIBERATION_MIN_SUPPORT
	)


## La couleur, c'est la liberté : gris dans une zone du régime, couleur une fois libre
## (et hors de tout territoire, comme la zone d'essai).
func saturation(zone_id: String) -> float:
	if not _zones.has(zone_id) or is_liberated(zone_id):
		return FREE_SATURATION
	return REGIME_SATURATION


func is_liberated(zone_id: String) -> bool:
	var zone: Dictionary = _zones.get(zone_id, {})
	return zone.get("liberated", false)


## Libère la zone. Rend false si elle est inconnue ou déjà libre.
func liberate(zone_id: String) -> bool:
	if not _zones.has(zone_id) or is_liberated(zone_id):
		return false
	_zones[zone_id]["liberated"] = true
	liberated.emit(zone_id)
	changed.emit(zone_id)
	return true


func to_dict() -> Dictionary:
	return _zones.duplicate(true)


## Ne relit que les zones déclarées ; le reste est ignoré.
func from_dict(state: Dictionary) -> void:
	for zone_id: String in _zones:
		var saved := SaveCodec.table(state, zone_id)
		var zone: Dictionary = _zones[zone_id]
		for key: String in ["control", "support"]:
			zone[key] = clampi(int(SaveCodec.number(saved, key, zone[key])), 0, MAX_VALUE)
		zone["liberated"] = SaveCodec.flag(saved, "liberated", zone["liberated"])
		changed.emit(zone_id)


func _value(zone_id: String, key: String) -> int:
	var zone: Dictionary = _zones.get(zone_id, {})
	return zone.get(key, 0)


func _add(zone_id: String, key: String, amount: int) -> void:
	if not _zones.has(zone_id):
		return
	_zones[zone_id][key] = clampi(_value(zone_id, key) + amount, 0, MAX_VALUE)
	changed.emit(zone_id)
