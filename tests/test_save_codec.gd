extends GutTest


func test_round_trip_keeps_systems() -> void:
	var systems := {"player": {"position": [1.5, 0.0, -2.0]}}
	var text := SaveCodec.encode(systems, "2026-11-11T12:00:00")
	var data := SaveCodec.decode(text)
	assert_eq(data["save_version"], SaveCodec.CURRENT_VERSION)
	assert_eq(data["saved_at"], "2026-11-11T12:00:00")
	assert_eq(data["systems"]["player"]["position"], [1.5, 0.0, -2.0])


func test_decode_rejects_unreadable_text() -> void:
	var texts: Array[String] = [
		"", "pas du json", "[1, 2]", "{}", '{"save_version": "x"}', '{"save_version": 1}'
	]
	for text: String in texts:
		assert_eq(SaveCodec.decode(text), {}, text)


func test_decode_rejects_a_newer_version() -> void:
	var text := JSON.stringify({"save_version": SaveCodec.CURRENT_VERSION + 1, "systems": {}})
	assert_eq(SaveCodec.decode(text), {})


func test_migrate_applies_each_step_in_order() -> void:
	var migrations := {1: _rename_hero, 2: _add_water}
	var data := SaveCodec.migrate({"save_version": 1, "systems": {"hero": {}}}, migrations, 3)
	assert_eq(data["save_version"], 3)
	assert_eq(data["systems"], {"player": {"water": 100}})


func test_migrate_fails_when_a_step_is_missing() -> void:
	assert_eq(SaveCodec.migrate({"save_version": 1, "systems": {}}, {}, 2), {})


func _rename_hero(data: Dictionary) -> Dictionary:
	data["systems"]["player"] = data["systems"]["hero"]
	data["systems"].erase("hero")
	return data


func _add_water(data: Dictionary) -> Dictionary:
	data["systems"]["player"]["water"] = 100
	return data
