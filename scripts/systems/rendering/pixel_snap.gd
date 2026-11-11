class_name PixelSnap
## Maths du « pixel parfait » : échelle entière de l'image basse résolution et calage
## de la caméra sur la grille de pixels.
##
## Une caméra orthographique qui glisse d'une fraction de pixel fait scintiller tout le
## décor. On la cale donc sur la grille (snap_position), puis on rattrape le reste en
## décalant l'image agrandie de quelques pixels d'écran (display_offset).

const BASE_SIZE := Vector2i(640, 360)
const PIXELS_PER_METER := 16.0
const TEXEL := 1.0 / PIXELS_PER_METER
## Pixels basse résolution rendus en plus autour de la vue, pour pouvoir la décaler.
const MARGIN := 1


## Plus grand agrandissement entier pour lequel la vue de base tient dans la fenêtre.
static func integer_scale(window_size: Vector2i) -> int:
	@warning_ignore("integer_division")
	return maxi(1, mini(window_size.x / BASE_SIZE.x, window_size.y / BASE_SIZE.y))


## Taille du rendu basse résolution qui couvre toute la fenêtre (sans la marge).
static func low_res_size(window_size: Vector2i, scale: int) -> Vector2i:
	return Vector2i(ceili(window_size.x / float(scale)), ceili(window_size.y / float(scale)))


## Cale la position sur la grille le long de la droite et du haut de la caméra.
## La profondeur (axe de visée) reste intacte.
static func snap_position(position: Vector3, camera_basis: Basis, texel: float) -> Vector3:
	var local := position * camera_basis
	return camera_basis * Vector3(snappedf(local.x, texel), snappedf(local.y, texel), local.z)


## Décalage à appliquer à l'image, en pixels basse résolution et en repère écran
## (x à droite, y vers le bas), pour qu'elle paraisse rendue depuis `position`.
static func display_offset(
	position: Vector3, snapped: Vector3, camera_basis: Basis, texel: float
) -> Vector2:
	var error := (position - snapped) * camera_basis / texel
	return Vector2(-error.x, error.y)
