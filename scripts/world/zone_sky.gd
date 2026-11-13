class_name ZoneSky
extends Node3D
## Lumière et ambiance d'un lieu. Dehors, le soleil et l'ambiance suivent l'heure du jeu
## (DayLight) ; dedans, une lumière égale, sur un fond uni : on ne voit pas dehors.

# Lumière d'intérieur. En renderer Compatibility, un soleil qui projette des ombres est
# dessiné dans une passe à part, ajoutée à l'ambiance après la conversion sRGB : les deux
# parts s'additionnent donc en sRGB. Ici 62 % d'ambiance + 38 % de soleil sur un sol :
# il reçoit tout juste sa couleur (une couleur de la palette reste nette, sans tramage)
# et une ombre garde 62 % de sa clarté.
const INTERIOR_AMBIENT_COLOR := Color.WHITE
const INTERIOR_AMBIENT_ENERGY := 0.35
const INTERIOR_SUN_ENERGY := 0.155
## Paramètre global des shaders : 0 en plein jour, 1 en pleine nuit (fenêtres, lanternes).
const NIGHT_PARAMETER := &"night_factor"
const REFRESH_SECONDS := 0.25
const SUN_MIN_ENERGY := 0.01

var _interior := false
var _age := REFRESH_SECONDS

@onready var _world_environment: WorldEnvironment = $WorldEnvironment
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	# L'environnement de la scène est partagé par tous les lieux : chacun a sa copie.
	_world_environment.environment = _world_environment.environment.duplicate()
	update_light()


func _process(delta: float) -> void:
	_age += delta
	if _age >= REFRESH_SECONDS:
		_age = 0.0
		update_light()


## Un intérieur baigne dans une lumière égale, sur un fond uni : on ne voit pas dehors.
func use_interior_light(background: Color) -> void:
	_interior = true
	var environment := _world_environment.environment
	environment.background_color = background
	environment.ambient_light_color = INTERIOR_AMBIENT_COLOR
	environment.ambient_light_energy = INTERIOR_AMBIENT_ENERGY
	_sun.light_energy = INTERIOR_SUN_ENERGY
	_sun.visible = true


## Applique la lumière de l'heure qu'il est.
func update_light() -> void:
	RenderingServer.global_shader_parameter_set(NIGHT_PARAMETER, GameState.clock.night_factor())
	if _interior:
		return
	var light := DayLight.sample(GameState.clock.minutes)
	var environment := _world_environment.environment
	environment.background_color = light["background"]
	environment.ambient_light_color = light["ambient_color"]
	environment.ambient_light_energy = light["ambient_energy"]
	_sun.light_color = light["sun_color"]
	_sun.light_energy = light["sun_energy"]
	_sun.visible = light["sun_energy"] > SUN_MIN_ENERGY
	if _sun.visible:
		_sun.global_basis = Basis.looking_at(light["sun_direction"], Vector3.UP)
