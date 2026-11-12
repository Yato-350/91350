class_name ZoneSky
extends Node3D
## Lumière et ambiance d'un lieu : soleil et environnement.
## (Le cycle jour/nuit le pilotera ; pour l'instant, une fin d'après-midi fixe.)

const INTERIOR_AMBIENT_ENERGY := 0.6
const INTERIOR_SUN_ENERGY := 0.5

@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun


## Un intérieur baigne dans une lumière égale, sur un fond uni : on ne voit pas dehors.
func use_interior_light(background: Color) -> void:
	# L'environnement est partagé par toutes les instances de la scène : on en fait une copie.
	var environment: Environment = _world_environment.environment.duplicate()
	environment.background_color = background
	environment.ambient_light_energy = INTERIOR_AMBIENT_ENERGY
	_world_environment.environment = environment
	_sun.light_energy = INTERIOR_SUN_ENERGY
