class_name LampLights
extends Node3D
## La nuit, les lampadaires et les appliques des entrées éclairent la rue. Il y en a des
## centaines : seules les POOL_SIZE plus proches d'Akan reçoivent une vraie lumière (en
## renderer Compatibility, chaque lumière coûte une passe de plus sur ce qu'elle touche).

const POOL_SIZE := 6
const COLOR := Color(1.0, 0.616, 0.227)
const ENERGY := 1.6
const RANGE := 10.0
## En dessous de ce degré de nuit, tout reste éteint.
const NIGHT_THRESHOLD := 0.3
const REFRESH_SECONDS := 0.3

## Où sont les lanternes (en mètres).
var positions := PackedVector3Array()
var player: Node3D

var _lights: Array[OmniLight3D] = []
var _age := REFRESH_SECONDS


func _ready() -> void:
	for index: int in POOL_SIZE:
		var light := OmniLight3D.new()
		light.name = "Lamp%d" % index
		light.light_color = COLOR
		light.omni_range = RANGE
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)
	update_lights()


func _process(delta: float) -> void:
	_age += delta
	if _age >= REFRESH_SECONDS:
		_age = 0.0
		update_lights()


## Rallume les lanternes les plus proches d'Akan, selon l'heure.
func update_lights() -> void:
	var night := GameState.clock.night_factor()
	var nearest: Array[Vector3] = []
	if night >= NIGHT_THRESHOLD and player != null and is_instance_valid(player):
		nearest = _nearest(player.global_position)
	for index: int in _lights.size():
		var light := _lights[index]
		light.visible = index < nearest.size()
		if light.visible:
			light.global_position = nearest[index]
			light.light_energy = ENERGY * night


func lit_count() -> int:
	return _lights.filter(func(light: OmniLight3D) -> bool: return light.visible).size()


## Distance du point à la lumière allumée la plus proche (INF si aucune).
func closest_light_distance(at: Vector3) -> float:
	var best := INF
	for light: OmniLight3D in _lights:
		if light.visible:
			best = minf(best, light.global_position.distance_to(at))
	return best


func _nearest(at: Vector3) -> Array[Vector3]:
	var sorted: Array[Vector3] = []
	for position: Vector3 in positions:
		sorted.append(position)
	sorted.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return a.distance_squared_to(at) < b.distance_squared_to(at)
	)
	return sorted.slice(0, POOL_SIZE)
