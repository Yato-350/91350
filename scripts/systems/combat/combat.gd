class_name Combat
## Les règles du corps à corps, en logique pure. Akan ne tue pas : ses coups mettent
## hors d'état. Un Vigile tombe en trois coups ; Akan en encaisse huit.

const PUNCH_DAMAGE := 20.0
const PUNCH_REACH := 1.5
const PUNCH_ARC_DEGREES := 70.0
const PUNCH_COOLDOWN := 0.35
## Par derrière, sans avoir été repéré : une neutralisation silencieuse, d'un coup.
const TAKEDOWN_REACH := 1.4
## Derrière = la cible tourne le dos : l'attaquant est hors de son demi-cône arrière.
const BEHIND_DOT := -0.3


## Les cibles devant l'attaquant, à portée, de la plus proche à la plus lointaine.
static func targets_in_front(
	at: Vector3, yaw: float, reach: float, arc_degrees: float, candidates: Array[Node3D]
) -> Array[Node3D]:
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var found: Array[Node3D] = []
	for candidate: Node3D in candidates:
		var offset := Vector2(
			candidate.global_position.x - at.x, candidate.global_position.z - at.z
		)
		if offset.length() > reach:
			continue
		if (
			offset.length() > 0.05
			and forward.dot(offset.normalized()) < cos(deg_to_rad(arc_degrees))
		):
			continue
		found.append(candidate)
	found.sort_custom(
		func(a: Node3D, b: Node3D) -> bool:
			return (
				a.global_position.distance_squared_to(at)
				< b.global_position.distance_squared_to(at)
			)
	)
	return found


## Vrai si `attacker_at` est dans le dos de quelqu'un qui regarde selon `target_yaw`.
static func is_behind(target_at: Vector3, target_yaw: float, attacker_at: Vector3) -> bool:
	var facing := Vector2(-sin(target_yaw), -cos(target_yaw))
	var to_attacker := Vector2(attacker_at.x - target_at.x, attacker_at.z - target_at.z)
	return to_attacker.length() < 0.01 or facing.dot(to_attacker.normalized()) < BEHIND_DOT
