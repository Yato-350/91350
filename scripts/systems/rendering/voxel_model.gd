class_name VoxelModel
## Charge les modèles voxel produits par tools/build_voxels.py (assets/voxel/**.glb) et
## leur donne le matériau qui affiche leurs couleurs par sommet.

const PATH := "res://assets/voxel/%s.glb"
const MATERIAL := preload("res://assets/materials/vertex_color.tres")


## Rend une instance du modèle `id` (« props/lit », « items/batte », « characters/akan »),
## ou null (erreur journalisée) s'il n'existe pas.
static func instantiate(id: String) -> Node3D:
	var path := PATH % id
	if not ResourceLoader.exists(path):
		push_error("Modèle voxel introuvable : %s" % id)
		return null
	var scene: PackedScene = load(path)
	var model: Node3D = scene.instantiate()
	for part: MeshInstance3D in parts(model):
		part.material_override = MATERIAL
	return model


## Les parties du modèle : un maillage par partie articulée.
static func parts(model: Node3D) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		found.append(node as MeshInstance3D)
	return found


## Boîte englobante du modèle, dans son propre repère.
static func bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for part: MeshInstance3D in parts(model):
		var transform := part.transform
		var parent := part.get_parent() as Node3D
		while parent != null and parent != model:
			transform = parent.transform * transform
			parent = parent.get_parent() as Node3D
		var part_box := transform * part.get_aabb()
		box = part_box if first else box.merge(part_box)
		first = false
	return box
