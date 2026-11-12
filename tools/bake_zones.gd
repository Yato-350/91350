extends SceneTree
## Construit la géométrie de chaque zone à partir des données dérivées d'OpenStreetMap
## et l'enregistre dans scenes/zones/generated/<zone>.scn.
##
##   tools/godot.sh --headless --path . -s tools/bake_zones.gd [zone…]

const ZONES := "res://tools/osm_import/zones.json"
const SOURCE := "res://tools/osm_import/data/%s.json"
const OUTPUT := "res://scenes/zones/generated/%s.scn"


func _initialize() -> void:
	var zones: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ZONES))
	var wanted := OS.get_cmdline_user_args()
	var palette := Palette.load_colors()
	var failures := 0
	for zone_id: String in zones:
		if not wanted.is_empty() and zone_id not in wanted:
			continue
		if not _bake(zone_id, palette):
			failures += 1
	quit(1 if failures > 0 else 0)


func _bake(zone_id: String, palette: Dictionary) -> bool:
	var source := SOURCE % zone_id
	if not FileAccess.file_exists(source):
		printerr("Données absentes : %s (lancer tools/osm_import/run.py %s)" % [source, zone_id])
		return false
	var zone: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var geometry := ZoneGeometryBuilder.build(zone, palette)
	var scene := PackedScene.new()
	var error := scene.pack(geometry)
	if error == OK:
		error = ResourceSaver.save(scene, OUTPUT % zone_id, ResourceSaver.FLAG_COMPRESS)
	geometry.free()
	if error != OK:
		printerr("Échec de l'enregistrement de %s (erreur %d)" % [zone_id, error])
		return false
	print("Zone cuite : ", OUTPUT % zone_id)
	return true
