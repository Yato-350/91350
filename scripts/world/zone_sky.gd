class_name ZoneSky
extends Node3D
## Lumière et ambiance d'un lieu : soleil et environnement.
## (Le cycle jour/nuit le pilotera ; pour l'instant, une fin d'après-midi fixe.)

# Lumière d'intérieur. En renderer Compatibility, un soleil qui projette des ombres est
# dessiné dans une passe à part, ajoutée à l'ambiance après la conversion sRGB : les deux
# parts s'additionnent donc en sRGB. Ici 62 % d'ambiance + 38 % de soleil sur un sol :
# il reçoit tout juste sa couleur (une couleur de la palette reste nette, sans tramage)
# et une ombre garde 62 % de sa clarté.
const INTERIOR_AMBIENT_COLOR := Color.WHITE
const INTERIOR_AMBIENT_ENERGY := 0.35
const INTERIOR_SUN_ENERGY := 0.155

@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun


## Un intérieur baigne dans une lumière égale, sur un fond uni : on ne voit pas dehors.
func use_interior_light(background: Color) -> void:
	# L'environnement est partagé par toutes les instances de la scène : on en fait une copie.
	var environment: Environment = _world_environment.environment.duplicate()
	environment.background_color = background
	environment.ambient_light_color = INTERIOR_AMBIENT_COLOR
	environment.ambient_light_energy = INTERIOR_AMBIENT_ENERGY
	_world_environment.environment = environment
	_sun.light_energy = INTERIOR_SUN_ENERGY
