class_name ZoneGeometry
extends Node3D
## Géométrie statique d'une zone, produite par ZoneGeometryBuilder à partir des données
## dérivées d'OpenStreetMap, puis enregistrée dans une scène par tools/bake_zones.gd.

@export var zone_id := ""
@export var zone_size := Vector2.ZERO
## Mention obligatoire (licence ODbL) : à afficher dans les crédits.
@export var attribution := ""
@export var nav_data: ZoneNavData
