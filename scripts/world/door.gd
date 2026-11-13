class_name Door
extends Interactable
## Un passage vers un autre lieu : un paillasson au sol, et « interact » pour passer.

const MAT_SIZE := 0.8
## Juste au-dessus du sol, pour ne pas se battre avec lui à l'affichage.
const MAT_HEIGHT := 0.03
const MAT_COLOR := "orange_sombre"

## Le lieu où mène la porte : « hall_tour », « grigny2@tour_akan ».
var target := ""
## [fichier, entrée] d'un dialogue joué à la place du passage : on frappe, et c'est
## lui qui décide d'ouvrir (il appelle travel()).
var knock: Array = []


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * MAT_SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = Palette.load_colors()[MAT_COLOR]
	material.roughness = 1.0
	plane.material = material
	var mat := MeshInstance3D.new()
	mat.name = "Mat"
	mat.mesh = plane
	mat.position = Vector3.UP * MAT_HEIGHT
	add_child(mat)
	interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	if knock.size() == 2:
		EventBus.dialogue_requested.emit(knock[0], knock[1])
	else:
		EventBus.travel_requested.emit(target)
