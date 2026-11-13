class_name Prop
extends Node3D
## Un élément de décor en voxels : meuble, mobilier urbain, véhicule à l'arrêt.

const MODEL_FOLDER := "props/"


## Rend le décor `model_id` ; `solid` lui donne une collision à la taille du modèle.
static func create(model_id: String, solid: bool) -> Prop:
	var prop := Prop.new()
	prop.name = model_id.to_pascal_case()
	var model := VoxelModel.instantiate(MODEL_FOLDER + model_id)
	if model == null:
		return prop
	model.name = "Model"
	prop.add_child(model)
	if solid:
		var bounds := VoxelModel.bounds(model)
		var box := BoxShape3D.new()
		box.size = bounds.size
		MeshKit.add_body(prop, "Body", box, bounds.get_center())
	return prop
