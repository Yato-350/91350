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


func test_quests_four_to_eight_free_grigny() -> void:
	(
		GameState
		. quests
		. from_dict(
			{
				"ascenseur_en_panne": {"state": "done"},
				"la_file": {"state": "done"},
				"le_vieux_du_7e": {"state": "done"},
				"les_yeux_du_quartier": {"state": "active", "step": "toit"},
			}
		)
	)
	await _play_the_eyes_of_the_neighbourhood()
	await _play_the_first_tag()
	await _play_the_big_one()
	await _play_the_contact()
	await _play_the_tower_rises()


func test_the_contact_can_be_paid_or_delivered_to_zed() -> void:
	var before := {
		"le_grand": {"state": "done"}, "le_contact": {"state": "active", "step": "coursier"}
	}
	# Payer cher.
	GameState.quests.from_dict(before)
	GameState.give("billets", 40)
	await _go("zone:grigny2@passerelle")
	await _talk("emissaire", [1])
	assert_true(GameState.quests.is_done("le_contact"), "payé")
	assert_true(GameState.inventory.has("lance_pierre"))
	assert_eq(GameState.inventory.count("billets"), 0)
	# Livrer sans regarder.
	GameState.quests.from_dict(before)
	await _go("zone:grigny2@passerelle")
	await _talk("emissaire", [0])
	await _go("zone:grigny2@gare")
	await _talk("relais_zed")
	assert_true(GameState.quests.is_done("le_contact"), "livré")
	assert_false(GameState.inventory.has("colis_zed"))
	assert_eq(GameState.progression.reputation("reseau"), 10)
	assert_eq(GameState.progression.reputation("familles"), -10)


func test_bernard_can_be_denounced_or_driven_away() -> void:
	var before := {"la_tour_se_leve": {"state": "active", "step": "bernard"}}
	GameState.give("lettre_menaces")
	for choice: int in [0, 2]:
		GameState.quests.from_dict(before)
		for flag: String in ["bernard_denonce", "bernard_parti"]:
			GameState.set_flag(flag, false)
		await _go("zone:palier_11")
		await _talk("bernard", [choice])
		assert_true(GameState.quests.is_step("la_tour_se_leve", "voisins"), "choix %d" % choice)
		await wait_seconds(Zone.CONDITION_REFRESH_SECONDS + 0.2)
		assert_null(_npc("bernard"), "Bernard est parti (choix %d)" % choice)


# 4. Les yeux du quartier
func _play_the_eyes_of_the_neighbourhood() -> void:
	await _go("zone:palier_11")
	assert_not_null(_door_to("toit_tour"), "l'escalier du toit est ouvert")
	await _go("zone:toit_tour")
	await _talk("ines", [0])
	assert_eq(GameState.inventory.count("provisions_guet"), 3)
	assert_true(GameState.has_flag(SecurityCamera.MAP_FLAG), "la carte des caméras")
	assert_true(GameState.is_offending(), "le matériel de guet rend suspect")
	await _go("zone:grigny2@poste_coteau")
	await _talk("jo")
	assert_true(GameState.quests.is_step("les_yeux_du_quartier", "parking"), "poste 1")
	await _go("zone:grigny2@poste_parking")
	EventBus.player_spotted.emit(Vector3.ZERO, "essai")
	await _talk("sandra")
	assert_true(GameState.quests.is_step("les_yeux_du_quartier", "parking"), "grillé : refusé")
	GameState.surveillance.note_spotted(-Surveillance.HOT_SECONDS * 2.0)
	await _talk("sandra")
	await _go("zone:grigny2@poste_conteneurs")
	await _talk("nadia")
	assert_false(GameState.is_offending(), "plus rien d'interdit dans le sac")
	await _go("zone:toit_tour")
	await _talk("ines")
	assert_true(GameState.quests.is_done("les_yeux_du_quartier"), "quête 4")
	assert_gte(GameState.progression.reputation("collectif"), 10)


# 5. Premier tag
func _play_the_first_tag() -> void:
	await _go("zone:grigny2@pixel")
	await _talk("pixel")
	await _go("zone:grigny2@derriere_la_tour")
	await _take("bombe_peinture")
	assert_true(GameState.quests.is_step("premier_tag", "tag"))
	GameState.clock.minutes = 22 * GameClock.MINUTES_PER_HOUR
	await _go("zone:grigny2@mur_tag")
	var wall := _spot("mur_tag")
	assert_true(wall.enabled, "la nuit, avec la bombe")
	wall.interact(_main.get_player())
	await _finish_dialogue([1])
	assert_true(GameState.has_flag("tag_espoir"))
	assert_true(Neighbourhood.new().hot(), "l'alarme est donnée")
	await wait_physics_frames(SETTLE)
	assert_not_null(_zone().get_node_or_null("TagEspoir"), "la fresque est sur le mur")
	await _go("zone:appartement_akan")
	assert_true(GameState.quests.is_done("premier_tag"), "quête 5")
	assert_true(GameState.has_flag("avis_recherche"))
	GameState.clock.minutes = 10 * GameClock.MINUTES_PER_HOUR


# 6. Le Grand
func _play_the_big_one() -> void:
	await _go("zone:appartement_lucien")
	await _talk("lucien")
	await _go("zone:salle_boxe")
	await _talk("le_grand", [0])
	assert_eq(GameState.inventory.count("bidon_plein"), 3)
	await _go("zone:palier_11")
	await _talk("huguette")
	await _go("zone:palier_7")
	await _talk("ferreira")
	await _go("zone:appartement_lucien")
	await _talk("lucien")
	assert_true(GameState.quests.is_step("le_grand", "paos"), "trois bidons livrés")
	await _go("zone:salle_boxe")
	await _talk("mamie_scooter", [0, 0, 1, 1, 2, 0])
	var points := GameState.progression.skill_points
	await _talk("le_grand", [2])
	assert_true(GameState.quests.is_done("le_grand"), "quête 6")
	assert_gt(GameState.progression.skill_points, points, "un point de compétence")


# 7. Le contact : rendre les tickets à Tata Rose
func _play_the_contact() -> void:
	await _go("zone:grigny2@passerelle")
	assert_true(GameState.quests.is_step("le_contact", "coursier"))
	await _talk("emissaire", [0])
	assert_true(GameState.inventory.has("colis_zed"))
	await _go("zone:grigny2@panier")
	await _talk("tata_rose", [0])
	assert_true(GameState.quests.is_step("le_contact", "cle"), "les tickets sont rendus")
	await _go("zone:grigny2@garage")
	await _talk("cle_de_12")
	assert_true(GameState.quests.is_done("le_contact"), "quête 7")
	assert_true(GameState.inventory.has("lance_pierre"))


# 8. La tour se lève
func _play_the_tower_rises() -> void:
	await _go("zone:hall_tour")
	assert_not_null(_door_to("local_tour"), "le local est ouvert")
	await _go("zone:local_tour")
	await _talk("wifi")
	await _go("zone:hall_tour")
	_spot("boitier").interact(_main.get_player())
	await _finish_dialogue([0])
	var camera := _zone().get_node("CameraHall") as SecurityCamera
	assert_true(camera.disabled, "la caméra du hall est aveugle")
	for spot_id: String in ["boites", "poubelle"]:
		_spot(spot_id).interact(_main.get_player())
		await _finish_dialogue()
	await _go("zone:palier_11")
	_spot("rebord").interact(_main.get_player())
	await _finish_dialogue()
	assert_true(GameState.quests.is_step("la_tour_se_leve", "bernard"), "trois indices")
	await _talk("bernard", [1])
	assert_true(GameState.has_flag("bernard_double"), "Bernard retourné")
	await _talk("huguette")
	await _go("zone:palier_7")
	await _talk("ferreira")
	await _go("zone:appartement_lucien")
	await _talk("lucien")
	await _go("zone:appartement_akan@daronne")
	await _talk("daronne")
	await _go("zone:hall_tour")
	await _talk("gardienne")
	assert_true(GameState.quests.is_step("la_tour_se_leve", "defendre"), "cinq voisins")
	assert_not_null(_npc("foule_huguette"), "les voisins descendent au hall")
	for wave: int in 3:
		await wait_physics_frames(SETTLE)
		var enemies := _enemies()
		assert_gt(enemies.size(), 0, "vague %d" % (wave + 1))
		for vigile: Vigile in enemies:
			vigile.knock_out()
	await _finish_dialogue()
	assert_true(GameState.territory.is_liberated("grigny2"), "Grigny 2 est libre")
	await _go("zone:local_tour")
	assert_true(GameState.quests.is_done("la_tour_se_leve"), "quête 8")
	await _go("zone:grigny2")
	assert_eq(_enemies().size(), 0, "plus de Vigiles")
	var cameras := _zone().get_children().filter(
		func(node: Node) -> bool: return node is SecurityCamera
	)
	assert_eq(cameras.size(), 0, "plus de caméras")
	var view: PixelView = _main.get_node("PixelView")
	assert_almost_eq(view.saturation, Territory.FREE_SATURATION, 0.01, "les couleurs")


# --- Gestes du joueur ---------------------------------------------------------


func _zone() -> Zone:
	var view: PixelView = _main.get_node("PixelView")
	return view.get_zone() as Zone


func _spot(spot_id: String) -> Spot:
	var spot := _zone().get_node_or_null("Spot" + spot_id.to_pascal_case()) as Spot
	assert_not_null(spot, spot_id)
	return spot


func _enemies() -> Array[Vigile]:
	var found: Array[Vigile] = []
	for node: Node in _zone().get_children():
		var vigile := node as Vigile
		if vigile != null and vigile.state != Vigile.State.KNOCKED_OUT:
			found.append(vigile)
	return found


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
