class_name PropInstances
extends MultiMeshInstance3D
## Des copies d'un même modèle de décor, dessinées d'un coup (MultiMesh).
##
## Les positions sont gardées ici, et le MultiMesh n'est rempli qu'au chargement : sans
## affichage (cuisson des zones, tests), le serveur de rendu ne garde pas ses données, et
## une scène enregistrée perdrait tous ses arbres.

@export var model := ""
@export var instance_mesh: Mesh
@export var transforms: Array[Transform3D] = []


func _ready() -> void:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = instance_mesh
	instances.instance_count = transforms.size()
	for index: int in transforms.size():
		instances.set_instance_transform(index, transforms[index])
	multimesh = instances
