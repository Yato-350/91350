extends GutTest
## Le robot de parcours : il joue l'acte 1 comme un joueur, lieu par lieu, réplique par
## réplique, et vérifie que chaque quête se termine.

const SCENE := preload("res://scenes/main/main.tscn")
const SETTLE := 3
const MAX_LINES := 60

var _main: Main
var _balloon: DialogueBalloon


func before_each() -> void:
	GameState.new_game()
	_main = SCENE.instantiate()
	add_child_autofree(_main)
	await wait_process_frames(SETTLE)
	_balloon = _main.get_node("UI/Balloon")
	GameState.quests.start(GameState.FIRST_QUEST)


func after_each() -> void:
	get_tree().paused = false


func test_the_first_three_quests_play_from_start_to_end() -> void:
	# 1. Ascenseur en panne
	await _go("zone:appartement_akan")
	await _talk("daronne")
	assert_true(GameState.quests.is_step("ascenseur_en_panne", "boire"))
	await _press("quick_1")
	await _press("quick_2")
	await _take("bidon_vide")
	await _go("zone:palier_11")
	await _walk_to("ascenseur")
	await _finish_dialogue()
	await _go("zone:palier_7@escalier_haut")
	await _go("zone:hall_tour@escalier")
	assert_true(GameState.quests.is_done("ascenseur_en_panne"), "quête 1")
	# 2. La file
	await _go("zone:grigny2@point_ration")
	assert_true(GameState.quests.is_step("la_file", "controle"))
	await _talk("vigile_ration", [2, 2])
	assert_true(GameState.has_flag("sac_paul"), "diversion réussie")
	assert_true(GameState.has_flag("paul_embarque"))
	assert_true(GameState.quests.is_step("la_file", "rapporter"))
	await wait_process_frames(SETTLE)
	assert_null(_npc("monsieur_paul"), "Monsieur Paul a été emmené")
	await _go("zone:appartement_akan@daronne")
	await _talk("daronne")
	assert_true(GameState.quests.is_done("la_file"), "quête 2")
	# 3. Le Vieux du 7e
	assert_true(GameState.quests.is_step("le_vieux_du_7e", "bernard"))
	await _go("zone:palier_11")
	await _talk("bernard")
	await _go("zone:grigny2@epicerie")
	await _talk("tonton")
	assert_true(GameState.quests.is_step("le_vieux_du_7e", "frapper"))
	await _go("zone:palier_7")
	await _walk_to("porte_lucien")
	assert_true(GameState.quests.is_step("le_vieux_du_7e", "livrer"))
	var door := _door_to("appartement_lucien")
	door.interact(_main.get_player())
	await _finish_dialogue([0])
	await wait_seconds(Main.TRAVEL_FADE_SECONDS * 2.0 + 0.2)
	assert_eq(GameState.place_id(), "appartement_lucien", "Lucien a ouvert")
	await _talk("lucien")
	assert_true(GameState.quests.is_done("le_vieux_du_7e"), "quête 3")
	assert_true(GameState.inventory.has("liste_disparus"))
	assert_true(GameState.has_flag("radio"))
	assert_eq(GameState.progression.reputation("anciens"), 10)


# --- Gestes du joueur ---------------------------------------------------------


func _go(place: String) -> void:
	assert_true(_main.travel_to(place), place)
	await wait_physics_frames(SETTLE)


func _walk_to(marker: String) -> void:
	var view: PixelView = _main.get_node("PixelView")
	var zone := view.get_zone() as Zone
	_main.get_player().teleport(zone.marker_position(marker) + Vector3.UP * 0.1)
	await wait_physics_frames(SETTLE)


func _talk(npc_id: String, choices: Array = []) -> void:
	var npc := _npc(npc_id)
	assert_not_null(npc, npc_id)
	if npc == null:
		return
	npc.interact(_main.get_player())
	await _finish_dialogue(choices)


# Lit le dialogue jusqu'au bout ; à chaque choix, prend la réponse suivante de `choices`
# (la première par défaut).
func _finish_dialogue(choices: Array = []) -> void:
	await wait_process_frames(SETTLE)
	var picks := choices.duplicate()
	for line: int in MAX_LINES:
		if not _balloon.visible:
			return
		var responses := _balloon.find_child("Responses", true, false).get_children().filter(
			func(node: Node) -> bool: return not node.is_queued_for_deletion()
		)
		if responses.is_empty():
			_balloon.advance()
		else:
			var index: int = picks.pop_front() if not picks.is_empty() else 0
			(responses[index] as Button).pressed.emit()
		await wait_process_frames(SETTLE)
	fail_test("dialogue sans fin")


func _press(action: String) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
	await wait_process_frames(SETTLE)


func _take(item_id: String) -> void:
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var pickup := node as Pickup
		if pickup != null and pickup.item_id == item_id:
			pickup.interact(_main.get_player())
	await wait_process_frames(SETTLE)


func _npc(npc_id: String) -> Npc:
	var view: PixelView = _main.get_node("PixelView")
	return view.get_zone().get_node_or_null(npc_id.to_pascal_case()) as Npc


func _door_to(place: String) -> Door:
	for node: Node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var door := node as Door
		if door != null and door.target.begins_with(place):
			return door
	return null
