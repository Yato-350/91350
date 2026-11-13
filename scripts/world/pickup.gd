class_name Pickup
extends Interactable
## Un objet posé dans le monde, qu'Akan ramasse d'un geste.

## Drapeau posé quand l'objet a été pris : il ne reviendra pas.
const TAKEN_FLAG := "pris:%s"
const MODEL_FOLDER := "items/"
## Les objets sont petits : on les grossit et on les fait flotter pour qu'ils se voient.
const MODEL_SCALE := 2.0
const HOVER_HEIGHT := 0.25
const SPIN_SPEED := 1.5

var item_id := ""
var amount := 1
## Identifiant durable de l'objet dans son lieu ; vide pour un objet tombé du sac.
var pickup_id := ""

var _model: Node3D


static func create(item: String, count: int, id: String = "") -> Pickup:
	var pickup := Pickup.new()
	pickup.name = "Pickup%s" % item.to_pascal_case()
	pickup.item_id = item
	pickup.amount = count
	pickup.pickup_id = id
	pickup.prompt = "PROMPT_PRENDRE"
	pickup._model = VoxelModel.instantiate(MODEL_FOLDER + item)
	if pickup._model != null:
		pickup._model.name = "Model"
		pickup._model.scale = Vector3.ONE * MODEL_SCALE
		pickup._model.position.y = HOVER_HEIGHT
		pickup.add_child(pickup._model)
	pickup.interacted.connect(pickup._on_interacted)
	return pickup


func _process(delta: float) -> void:
	if _model != null:
		_model.rotate_y(SPIN_SPEED * delta)


# Prend ce qui tient dans le sac ; le reste attend par terre.
func _on_interacted(_player: Player) -> void:
	var left := GameState.inventory.add(item_id, amount)
	if left == amount:
		EventBus.notified.emit("HUD_BAG_FULL")
		return
	amount = left
	EventBus.sound_requested.emit(&"ramassage")
	if left > 0:
		return
	if not pickup_id.is_empty():
		GameState.set_flag(TAKEN_FLAG % pickup_id)
	queue_free()
