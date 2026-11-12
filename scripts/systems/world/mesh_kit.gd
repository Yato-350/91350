class_name MeshKit
## Aides de construction de maillages et de collisions, partagées par les constructeurs
## de géométrie (zones extérieures, intérieurs).


## Ajoute un triangle orienté vers `normal` (Godot : face avant = sens horaire).
## Ses sommets sont aussi ajoutés à `faces`, pour en faire une collision.
static func add_triangle(
	surface: SurfaceTool,
	faces: PackedVector3Array,
	corners: Array,
	normal: Vector3,
	color: Color,
	uvs: Array,
	uv2: Vector2
) -> void:
	var order: Array[int] = [0, 1, 2]
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		order = [0, 2, 1]
	for index: int in order:
		surface.set_normal(normal)
		surface.set_color(color)
		surface.set_uv(uvs[index])
		surface.set_uv2(uv2)
		surface.add_vertex(corners[index])
		faces.append(corners[index])


## Ajoute un quadrilatère uni (quatre coins dans l'ordre du tour) orienté vers `normal`.
static func add_quad(
	surface: SurfaceTool, corners: Array[Vector3], normal: Vector3, color: Color
) -> void:
	var unused := PackedVector3Array()
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		var picked: Array[Vector3] = []
		for corner: int in triangle:
			picked.append(corners[corner])
		add_triangle(surface, unused, picked, normal, color, uvs, Vector2.ZERO)


## Termine le maillage et l'attache à `parent` sous le nom `name`.
static func commit(
	parent: Node, name: String, surface: SurfaceTool, material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = name
	surface.index()
	var mesh := surface.commit()
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, material)
		instance.mesh = mesh
	parent.add_child(instance)
	return instance


## Ajoute à `parent` un corps statique d'une seule forme, placé en `at`.
static func add_body(parent: Node, name: String, shape: Shape3D, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = at
	add_shape(body, shape, Vector3.ZERO)
	parent.add_child(body)
	return body


static func add_shape(body: StaticBody3D, shape: Shape3D, at: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = "Shape" if body.get_child_count() == 0 else "Shape%d" % body.get_child_count()
	collision.shape = shape
	collision.position = at
	body.add_child(collision)


## Rend `owner` propriétaire de tous les descendants : sans cela, ils ne seraient pas
## enregistrés quand la géométrie est empaquetée dans une scène.
static func own(node: Node, owner: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner
		own(child, owner)
