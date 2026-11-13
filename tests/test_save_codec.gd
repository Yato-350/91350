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


func test_typed_readers_fall_back_on_missing_or_malformed_values() -> void:
	var state := {"n": 3, "f": 2.5, "s": "eau", "b": true, "d": {"a": 1}, "l": [1, 2]}
	assert_eq(SaveCodec.number(state, "n", 9.0), 3.0)
	assert_eq(SaveCodec.number(state, "f", 9.0), 2.5)
	assert_eq(SaveCodec.number(state, "s", 9.0), 9.0)
	assert_eq(SaveCodec.number(state, "absent", 9.0), 9.0)
	assert_eq(SaveCodec.text(state, "s", "x"), "eau")
	assert_eq(SaveCodec.text(state, "n", "x"), "x")
	assert_true(SaveCodec.flag(state, "b", false))
	assert_true(SaveCodec.flag(state, "n", true))
	assert_eq(SaveCodec.table(state, "d"), {"a": 1})
	assert_eq(SaveCodec.table(state, "l"), {})
	assert_eq(SaveCodec.list(state, "l"), [1, 2])
	assert_eq(SaveCodec.list(state, "d"), [])
