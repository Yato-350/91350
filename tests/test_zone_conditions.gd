extends GutTest
## Ce qui n'est là que sous condition : portes, personnages, décor, caméras. Le lieu le
## relit quand un drapeau change, quand une quête avance, quand une zone se libère, et
## de temps en temps pour les horaires.

const PLAN := {
	"id": "essai_conditions",
	"name": "PLACE_HALL_TOUR",
	"territory": "grigny2",
	"plan": ["########", "#a.b.x.#", "#....cn#", "########"],
	"markers": {"a": "default", "b": "porte", "c": "coin", "n": "nuit"},
	"props": {"x": {"model": "caisse", "if": {"flags": ["caisse_la"]}}},
	"doors": [{"at": "porte", "to": "hall_tour", "if": {"flags": ["porte_ouverte"]}}],
	"npcs":
	[
		{"id": "gus", "character": "civil_1", "at": "coin", "if": {"flags": ["gus_la"]}},
		{"id": "veilleur", "character": "civil_2", "at": "nuit", "if": {"hours": [21, 6]}},
	],
	"cameras": [{"id": "essai", "at": "coin", "if": {"not_liberated": ["grigny2"]}}],
}


func before_each() -> void:
	GameState.new_game()
	GameState.clock.minutes = 12 * 60.0


func after_each() -> void:
	GameState.new_game()


func test_a_door_opens_and_closes_with_its_condition() -> void:
	var zone := await _make(PLAN)
	assert_null(zone.get_node_or_null("Door_porte"))
	GameState.set_flag("porte_ouverte")
	await wait_process_frames(1)
	assert_not_null(zone.get_node_or_null("Door_porte"))
	GameState.set_flag("porte_ouverte", false)
	await wait_process_frames(1)
	assert_null(zone.get_node_or_null("Door_porte"))


func test_people_and_furniture_come_and_go() -> void:
	var zone := await _make(PLAN)
	assert_null(zone.get_node_or_null("Gus"))
	assert_eq(_props(zone, "Caisse"), 0)
	GameState.set_flag("gus_la")
	GameState.set_flag("caisse_la")
	await wait_process_frames(1)
	assert_not_null(zone.get_node_or_null("Gus"))
	assert_eq(_props(zone, "Caisse"), 1)
	GameState.set_flag("gus_la", false)
	await wait_process_frames(1)
	assert_null(zone.get_node_or_null("Gus"), "il s'en va")


func test_hours_are_read_again_as_time_goes_by() -> void:
	var zone := await _make(PLAN)
	assert_null(zone.get_node_or_null("Veilleur"))
	GameState.clock.minutes = 22 * 60.0
	await wait_seconds(Zone.CONDITION_REFRESH_SECONDS + 0.2)
	assert_not_null(zone.get_node_or_null("Veilleur"), "la nuit, il prend son poste")


func test_the_regime_leaves_a_liberated_zone() -> void:
	var zone := await _make(PLAN)
	assert_not_null(zone.get_node_or_null("CameraEssai"))
	GameState.territory.liberate("grigny2")
	await wait_process_frames(1)
	assert_null(zone.get_node_or_null("CameraEssai"))


func test_an_open_air_place_follows_the_time_of_day() -> void:
	var definition := PLAN.duplicate(true)
	definition["open_air"] = true
	var zone := await _make(definition)
	var sky: ZoneSky = null
	for child: Node in zone.get_children():
		if child is ZoneSky:
			sky = child
	var environment := (sky.get_node("WorldEnvironment") as WorldEnvironment).environment
	var expected: Color = DayLight.sample(GameState.clock.minutes)["background"]
	assert_eq(environment.background_color, expected, "le ciel, pas un fond d'intérieur")


func _make(definition: Dictionary) -> Zone:
	var zone := Zone.from_definition(definition["id"], definition, true)
	add_child_autofree(zone)
	await wait_process_frames(2)
	return zone


func _props(zone: Zone, prefix: String) -> int:
	var count := 0
	for child: Node in zone.get_children():
		if (
			child is Prop
			and String(child.name).begins_with(prefix)
			and not child.is_queued_for_deletion()
		):
			count += 1
	return count
