class_name ZoneNavData
extends Resource
## Grille de navigation d'une zone : une case par mètre, pleine (1) ou libre (0).
## La zone est centrée sur l'origine ; la case (0, 0) est son coin nord-ouest.

@export var size := Vector2i.ZERO
@export var cell_size := 1.0
@export var solid := PackedByteArray()


static func create(zone_size: Vector2, cell: float = 1.0) -> ZoneNavData:
	var data := ZoneNavData.new()
	data.cell_size = cell
	data.size = Vector2i(ceili(zone_size.x / cell), ceili(zone_size.y / cell))
	data.solid.resize(data.size.x * data.size.y)
	return data


func contains(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func cell_of(position: Vector3) -> Vector2i:
	return Vector2i(
		floori(position.x / cell_size + size.x / 2.0), floori(position.z / cell_size + size.y / 2.0)
	)


func center_of(cell: Vector2i) -> Vector3:
	return Vector3(
		(cell.x + 0.5 - size.x / 2.0) * cell_size, 0.0, (cell.y + 0.5 - size.y / 2.0) * cell_size
	)


func is_solid(cell: Vector2i) -> bool:
	return not contains(cell) or solid[cell.y * size.x + cell.x] != 0


## Hors de la zone, tout est plein.
func is_solid_at(position: Vector3) -> bool:
	return is_solid(cell_of(position))


func set_solid(cell: Vector2i, value: bool = true) -> void:
	if contains(cell):
		solid[cell.y * size.x + cell.x] = 1 if value else 0
