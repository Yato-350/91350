class_name PixelView
extends Control
## Compositeur du rendu « pixel 2.5D ».
##
## Le monde 3D est rendu dans un SubViewport (une petite « télé » basse résolution),
## puis agrandi à l'échelle entière par un SubViewportContainer, sans flou.
## À chaque image, PixelView cale la caméra orthographique sur la grille de pixels et
## rattrape le reste en décalant l'image agrandie : le défilement reste fluide et le
## décor ne scintille pas.
##
## Contrat : PixelView déplace la caméra. Son propriétaire doit donc la remettre à sa
## position idéale à chaque image.

signal scale_changed(scale: int)

## Passe après tout le gameplay : la caméra a alors sa position idéale de l'image.
const SNAP_PRIORITY := 1000
const OUTLINE_COLOR_ID := "noir"
const SHADER_PALETTE_SIZE := 32

@export var palette_path: String = Palette.PATH

## 0.0 = gris du régime, 1.0 = pleine couleur.
var saturation: float = 1.0:
	set(value):
		saturation = clampf(value, 0.0, 1.0)
		if is_node_ready():
			_grade_material.set_shader_parameter(&"saturation", saturation)

var _pixel_scale := 0
var _base_position := Vector2.ZERO
var _palette_size := 0
var _zone: Node3D
var _saturation_tween: Tween

@onready var _container: SubViewportContainer = $Container
@onready var _world: SubViewport = $Container/World
@onready var _outline_material: ShaderMaterial = $Container/World/Outline.material_override
@onready var _grade_material: ShaderMaterial = $Container/World/Grade/Rect.material


func _ready() -> void:
	process_priority = SNAP_PRIORITY
	_apply_palette()
	_grade_material.set_shader_parameter(&"saturation", saturation)
	resized.connect(_layout)
	EventBus.saturation_change_requested.connect(_on_saturation_change_requested)
	_layout()


func _process(_delta: float) -> void:
	var camera := _world.get_camera_3d()
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		_container.position = _base_position
		return
	camera.size = _world.size.y / PixelSnap.PIXELS_PER_METER
	var ideal := camera.global_position
	var camera_basis := camera.global_basis.orthonormalized()
	var snapped := PixelSnap.snap_position(ideal, camera_basis, PixelSnap.TEXEL)
	camera.global_position = snapped
	var offset := PixelSnap.display_offset(ideal, snapped, camera_basis, PixelSnap.TEXEL)
	_container.position = _base_position + (offset * _pixel_scale).round()


## Remplace la zone affichée ; l'ancienne est libérée.
func set_zone(zone: Node3D) -> void:
	if _zone != null:
		_world.remove_child(_zone)
		_zone.queue_free()
	_zone = zone
	if zone != null:
		_world.add_child(zone)


func get_zone() -> Node3D:
	return _zone


func get_world_viewport() -> SubViewport:
	return _world


func get_pixel_scale() -> int:
	return _pixel_scale


func get_palette_size() -> int:
	return _palette_size


## Image basse résolution, marge comprise, telle qu'elle sort des shaders.
func get_low_res_image() -> Image:
	return _world.get_texture().get_image()


# Recalcule l'agrandissement entier et la taille du rendu pour la taille actuelle.
func _layout() -> void:
	var window := Vector2i(size)
	var new_scale := PixelSnap.integer_scale(window)
	var margin := Vector2i.ONE * PixelSnap.MARGIN
	var low_res := PixelSnap.low_res_size(window, new_scale) + margin * 2
	_container.stretch_shrink = new_scale
	_container.size = Vector2(low_res * new_scale)
	_base_position = -Vector2(margin * new_scale)
	_container.position = _base_position
	if new_scale != _pixel_scale:
		_pixel_scale = new_scale
		scale_changed.emit(new_scale)


func _apply_palette() -> void:
	var colors := Palette.load_colors(palette_path)
	_palette_size = colors.size()
	var values := PackedVector3Array()
	values.resize(SHADER_PALETTE_SIZE)
	var index := 0
	for color: Color in colors.values():
		values[index] = Vector3(color.r, color.g, color.b)
		index += 1
	_grade_material.set_shader_parameter(&"palette", values)
	_grade_material.set_shader_parameter(&"palette_size", _palette_size)
	if colors.has(OUTLINE_COLOR_ID):
		_outline_material.set_shader_parameter(&"outline_color", colors[OUTLINE_COLOR_ID])


func _on_saturation_change_requested(target: float, duration: float) -> void:
	if _saturation_tween != null:
		_saturation_tween.kill()
	if duration <= 0.0:
		saturation = target
		return
	_saturation_tween = create_tween()
	_saturation_tween.tween_property(self, ^"saturation", target, duration)
