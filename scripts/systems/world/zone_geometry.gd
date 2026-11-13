class_name ZoneGeometry
extends Node3D
## Géométrie statique d'un lieu. Une zone extérieure est produite par ZoneGeometryBuilder
## à partir des données dérivées d'OpenStreetMap, puis enregistrée dans une scène par
## tools/bake_zones.gd ; un intérieur est construit au chargement par InteriorBuilder.

@export var zone_id := ""
@export var zone_size := Vector2.ZERO
## Mention obligatoire (licence ODbL) : à afficher dans les crédits.
@export var attribution := ""
@export var nav_data: ZoneNavData
## Repères posés par le plan d'un intérieur : nom → position (Vector3).
@export var markers := {}
## Lanternes des lampadaires (en mètres) : la nuit, les lumières y sont posées.
@export var lamp_positions := PackedVector3Array()
## Entrées des immeubles : {"position", "normal", "building", "kind"}.
@export var entrances: Array[Dictionary] = []
