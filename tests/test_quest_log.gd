extends GutTest

const QUESTS := {
	"eau":
	{
		"id": "eau",
		"steps":
		[
			{"id": "parler", "type": "TALK", "target": "daronne"},
			{"id": "bidons", "type": "COLLECT", "target": "bidon", "count": 2},
			{"id": "rendre", "type": "DELIVER", "target": "daronne"},
		],
	},
	"file":
	{
		"id": "file",
		"steps":
		[
			{
				"id": "controle",
				"type": "TALK",
				"target": "vigile",
				"branches": [{"type": "PUBLISH", "target": "diversion", "goto": "fuite"}],
			},
			{"id": "ration", "type": "COLLECT", "target": "eau", "end": true},
			{"id": "fuite", "type": "GOTO", "target": "hall"},
		],
	},
}

var _log: QuestLog


func before_each() -> void:
	_log = QuestLog.new(QUESTS)
	watch_signals(_log)


func test_starting_a_quest_opens_its_first_step() -> void:
	assert_false(_log.start("licorne"), "quête inconnue")
	assert_true(_log.start("eau"))
	assert_false(_log.start("eau"), "déjà commencée")
	assert_true(_log.is_active("eau"))
	assert_true(_log.is_step("eau", "parler"))
	assert_eq(_log.current_step("eau")["type"], "TALK")
	assert_signal_emitted_with_parameters(_log, "quest_started", ["eau"])
	assert_eq(_log.active_ids(), ["eau"] as Array[String])


func test_only_the_matching_objective_advances_the_step() -> void:
	_log.start("eau")
	_log.notify("TALK", "tonton")
	_log.notify("GOTO", "daronne")
	assert_true(_log.is_step("eau", "parler"))
	_log.notify("TALK", "daronne")
	assert_true(_log.is_step("eau", "bidons"))
	assert_signal_emitted_with_parameters(_log, "step_completed", ["eau", "parler"])


func test_a_counted_objective_needs_its_whole_count() -> void:
	_log.start("eau")
	_log.notify("TALK", "daronne")
	_log.notify("COLLECT", "bidon")
	assert_eq(_log.progress("eau"), 1)
	assert_true(_log.is_step("eau", "bidons"))
	_log.notify("COLLECT", "bidon", 3)
	assert_true(_log.is_step("eau", "rendre"))
	assert_eq(_log.progress("eau"), 0, "le compteur repart à zéro à chaque étape")


func test_finishing_the_last_step_completes_the_quest() -> void:
	_log.start("eau")
	_log.notify("TALK", "daronne")
	_log.notify("COLLECT", "bidon", 2)
	_log.notify("DELIVER", "daronne")
	assert_true(_log.is_done("eau"))
	assert_false(_log.is_active("eau"))
	assert_signal_emitted_with_parameters(_log, "quest_completed", ["eau"])
	assert_eq(_log.current_step("eau"), {})
	_log.notify("DELIVER", "daronne")
	assert_signal_emit_count(_log, "quest_completed", 1)


func test_a_branch_objective_jumps_to_another_step() -> void:
	_log.start("file")
	_log.notify("PUBLISH", "diversion")
	assert_true(_log.is_step("file", "fuite"))
	_log.notify("GOTO", "hall")
	assert_true(_log.is_done("file"))


func test_a_step_marked_end_completes_the_quest_without_the_following_steps() -> void:
	_log.start("file")
	_log.notify("TALK", "vigile")
	assert_true(_log.is_step("file", "ration"))
	_log.notify("COLLECT", "eau")
	assert_true(_log.is_done("file"))


func test_one_event_feeds_every_active_quest() -> void:
	_log.start("eau")
	_log.start("file")
	_log.notify("TALK", "vigile")
	assert_true(_log.is_step("eau", "parler"))
	assert_true(_log.is_step("file", "ration"))
	assert_eq(_log.active_ids(), ["eau", "file"] as Array[String])


func test_state_round_trips_and_ignores_what_it_does_not_know() -> void:
	_log.start("eau")
	_log.notify("TALK", "daronne")
	_log.notify("COLLECT", "bidon")
	_log.start("file")
	_log.notify("TALK", "vigile")
	_log.notify("COLLECT", "eau")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_log.to_dict()))
	saved["disparue"] = {"state": "active", "step": "x", "progress": 0}
	var copy := QuestLog.new(QUESTS)
	copy.from_dict(saved)
	assert_true(copy.is_step("eau", "bidons"))
	assert_eq(copy.progress("eau"), 1)
	assert_true(copy.is_done("file"))
	assert_false(copy.is_active("disparue"))
	copy.from_dict({"eau": {"state": "active", "step": "inconnue"}})
	assert_true(copy.is_step("eau", "parler"), "étape inconnue : on reprend au début")


func test_the_last_started_quest_is_the_tracked_one() -> void:
	assert_eq(_log.tracked_id(), "")
	_log.start("eau")
	_log.start("file")
	assert_eq(_log.tracked_id(), "file")
	_log.notify("TALK", "vigile")
	_log.notify("COLLECT", "eau")
	assert_eq(_log.tracked_id(), "eau", "file est finie")
