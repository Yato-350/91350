class_name Awareness
extends RefCounted
## La jauge d'attention d'un guetteur, de 0 à 1. Elle monte quand il voit Akan faire
## quelque chose d'interdit — vite de près, lentement de loin, deux fois moins vite s'il
## est accroupi — et redescend quand il le perd de vue. À 1, Akan est repéré : le joueur
## a toujours le temps de réagir.

## Temps pour passer de 0 à 1 : tout près, et à la limite de la portée.
const NEAR_SECONDS := 0.6
const FAR_SECONDS := 2.5
const CROUCH_FACTOR := 0.5
const DECAY_PER_SECOND := 0.4

var value := 0.0


func update(delta: float, seen: bool, distance: float, sight_range: float, crouched: bool) -> void:
	if not seen:
		value = maxf(value - DECAY_PER_SECOND * delta, 0.0)
		return
	var closeness := clampf(distance / maxf(sight_range, 0.01), 0.0, 1.0)
	var rate := 1.0 / lerpf(NEAR_SECONDS, FAR_SECONDS, closeness)
	if crouched:
		rate *= CROUCH_FACTOR
	value = minf(value + rate * delta, 1.0)


func is_suspicious() -> bool:
	return value > 0.0


func is_alerted() -> bool:
	return value >= 1.0
