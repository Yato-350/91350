class_name Vision
## Le regard d'un guetteur, en logique pure : portée, cône, puis ligne de vue sur la grille
## (du moins cher au plus cher). Repère : x vers l'est, z vers le sud ; un lacet nul regarde
## vers le nord (-z), comme l'avant des modèles.


## Vrai si un œil en `eye`, tourné de `yaw`, voit `target` : à portée, dans le cône de
## demi-angle `half_angle`, et sans rien d'opaque entre eux (si `nav` est donnée).
static func can_see(
	eye: Vector3,
	yaw: float,
	half_angle: float,
	sight_range: float,
	target: Vector3,
	nav: ZoneNavData
) -> bool:
	var to := Vector2(target.x - eye.x, target.z - eye.z)
	if to.length_squared() > sight_range * sight_range:
		return false
	var forward := Vector2(-sin(yaw), -cos(yaw))
	if to.length() > 0.01 and forward.dot(to.normalized()) < cos(half_angle):
		return false
	return nav == null or nav.line_of_sight(eye, target)
