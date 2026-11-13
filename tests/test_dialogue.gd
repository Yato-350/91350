extends GutTest

const FILE := "res://tests/dialogue/essai.dialogue"
const SETTLE_FRAMES := 3

var _balloon: DialogueBalloon


func before_each() -> void:
	GameState.new_game()
	_balloon = DialogueBalloon.new()
	add_child_autofree(_balloon)


func after_each() -> void:
	get_tree().paused = false


func test_a_dialogue_shows_who_speaks_and_pauses_the_game() -> void:
	assert_false(_balloon.visible)
	await _start("start")
	assert_true(_balloon.visible)
	assert_true(get_tree().paused)
	assert_eq(_text("Speaker"), tr("CHAR_TONTON"))
	assert_eq(_text("Text"), "Tu cherches Lucien ?")


func test_responses_show_their_tone_and_follow_their_branch() -> void:
	await _start("start")
	var responses := _responses()
	assert_eq(responses.size(), 2, "la troisième réponse demande des piles")
	assert_eq(responses[0].text, "[%s] Oui." % tr("TONE_CALME"))
	assert_eq(responses[1].text, "[%s] Non." % tr("TONE_CASH"))
	_balloon.advance()
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq(_text("Text"), "Tu cherches Lucien ?", "il faut choisir une réponse")
	responses[0].pressed.emit()
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq(_text("Text"), "Et moi je cherche quoi, à ton avis ? Des piles.")
	assert_eq(_responses().size(), 0)
	_balloon.advance()
	await wait_process_frames(SETTLE_FRAMES)
	assert_false(_balloon.visible)
	assert_false(get_tree().paused)
	assert_true(GameState.has_flag("piles_demandees"))
	assert_eq(GameState.inventory.count("piles"), 2)


func test_a_conditional_response_appears_only_when_allowed() -> void:
	GameState.give("piles", 1)
	await _start("start")
	assert_eq(_responses().size(), 3)


func test_conditions_read_the_story_and_unknown_speakers_keep_their_name() -> void:
	await _start("suite")
	assert_eq(_text("Speaker"), "Un inconnu")
	assert_eq(_text("Text"), "Je te connais, toi ?")
	_balloon.advance()
	await wait_process_frames(SETTLE_FRAMES)
	GameState.set_flag("piles_demandees")
	await _start("suite")
	assert_eq(_text("Text"), "Alors, ces piles ?")


func test_the_bus_starts_a_dialogue_and_hears_its_end() -> void:
	watch_signals(EventBus)
	EventBus.dialogue_requested.emit(FILE, "suite")
	await wait_process_frames(SETTLE_FRAMES)
	assert_true(_balloon.visible)
	EventBus.dialogue_requested.emit(FILE, "start")
	await wait_process_frames(SETTLE_FRAMES)
	assert_eq(_text("Text"), "Je te connais, toi ?", "un seul dialogue à la fois")
	_send_action("ui_accept")
	await wait_process_frames(SETTLE_FRAMES)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_ended", [FILE])
	assert_eq(_text("Text"), "Tu cherches Lucien ?", "le second dialogue attendait son tour")


func test_an_unknown_dialogue_is_refused() -> void:
	_balloon.start("licorne", "start")
	await wait_process_frames(SETTLE_FRAMES)
	assert_push_error("licorne")
	assert_false(_balloon.visible)
	assert_false(get_tree().paused)


func test_the_story_vocabulary_reads_and_changes_the_game() -> void:
	var story := Story.new()
	GameState.enter("zone:grigny2", "grigny2")
	story.give("piles", 3)
	assert_true(story.has("piles", 3))
	assert_true(story.take("piles", 2))
	assert_false(story.take("piles", 5))
	story.set_flag("radio")
	assert_true(story.flag("radio"))
	story.clear_flag("radio")
	assert_false(story.flag("radio"))
	story.rep("familles", 5)
	story.support(10)
	story.vigilance(1)
	story.xp(100)
	assert_eq(story.reputation("familles"), 5)
	assert_eq(GameState.territory.support("grigny2"), 25)
	assert_eq(GameState.surveillance.level("grigny2"), 1)
	assert_eq(GameState.progression.level, 2)
	watch_signals(EventBus)
	story.travel("hall_tour@escalier")
	assert_signal_emitted_with_parameters(EventBus, "travel_requested", ["hall_tour@escalier"])


func _start(cue: String) -> void:
	_balloon.start(FILE, cue)
	await wait_process_frames(SETTLE_FRAMES)


func _text(node_name: String) -> String:
	return _balloon.find_child(node_name, true, false).get("text")


func _responses() -> Array[Button]:
	var buttons: Array[Button] = []
	for node: Node in _balloon.find_child("Responses", true, false).get_children():
		if not node.is_queued_for_deletion():
			buttons.append(node as Button)
	return buttons


func _send_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
