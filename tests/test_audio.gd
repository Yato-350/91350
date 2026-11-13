extends GutTest
## Le son : les bus, les bruitages (prises et variations), la musique qui suit la couleur
## du lieu, la musique qui se tasse sous les dialogues. Le pilote audio factice joue en
## temps réel : « playing » et les fondus se vérifient sans haut-parleur.

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")


func after_each() -> void:
	AudioManager.play_music(&"", 0.0)
	AudioManager.play_ambience(&"")
	EventBus.dialogue_ended.emit("essai")
	GameState.new_game()


func test_the_bus_layout_routes_music_through_its_duck_bus() -> void:
	for bus: StringName in [&"Music", &"MusicDuck", &"SFX", &"Ambience", &"UI"]:
		assert_ne(AudioServer.get_bus_index(bus), -1, bus)
	var music := AudioServer.get_bus_index(&"Music")
	assert_eq(AudioServer.get_bus_send(music), &"MusicDuck")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index(&"MusicDuck")), &"Master")


func test_every_sound_has_its_files() -> void:
	for sound: StringName in AudioManager.SOUNDS:
		var spec: Dictionary = AudioManager.SOUNDS[sound]
		var takes: int = spec.get("takes", 1)
		for take: int in takes:
			var file := String(sound) if takes == 1 else "%s_%d" % [sound, take + 1]
			assert_true(ResourceLoader.exists(AudioManager.SOUND_PATH % file), file)
	for track: StringName in AudioManager.MUSIC:
		assert_true(ResourceLoader.exists(AudioManager.SOUND_PATH % AudioManager.MUSIC[track]))


func test_a_sound_plays_on_its_bus() -> void:
	AudioManager.play(&"coup")
	var player := _player_of(&"SFX")
	assert_not_null(player, "un lecteur joue sur le bus des effets")


func test_an_unknown_sound_is_reported() -> void:
	AudioManager.play(&"licorne")
	assert_push_error("licorne")


func test_music_loops_and_crossfades() -> void:
	AudioManager.play_music(&"libre", 0.0)
	assert_eq(AudioManager.music(), &"libre")
	var stream := load(AudioManager.SOUND_PATH % AudioManager.MUSIC[&"libre"]) as AudioStreamWAV
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "la boucle vient du fichier")
	AudioManager.play_music(&"regime", 0.1)
	await wait_seconds(0.3)
	var playing := _players_on(&"Music")
	assert_eq(playing.size(), 1, "l'ancienne musique s'est tue")
	assert_eq(
		playing[0].stream.resource_path, AudioManager.SOUND_PATH % AudioManager.MUSIC[&"regime"]
	)


func test_music_steps_back_under_a_dialogue() -> void:
	var duck := AudioServer.get_bus_index(&"MusicDuck")
	EventBus.dialogue_requested.emit("essai", "start")
	await wait_seconds(AudioManager.DUCK_SECONDS + 0.1)
	assert_almost_eq(AudioServer.get_bus_volume_db(duck), AudioManager.DUCK_DB, 0.1)
	EventBus.dialogue_ended.emit("essai")
	await wait_seconds(AudioManager.DUCK_SECONDS + 0.1)
	assert_almost_eq(AudioServer.get_bus_volume_db(duck), 0.0, 0.1)


func test_events_of_the_game_make_their_sounds() -> void:
	watch_signals(EventBus)
	Neighbourhood.new().sound("bombe")
	assert_signal_emitted_with_parameters(EventBus, "sound_requested", [&"bombe"])


func test_akan_walks_with_footsteps_but_crouches_in_silence() -> void:
	var player: Player = PLAYER_SCENE.instantiate()
	add_child_autofree(player)
	var heard: Array[StringName] = []
	var listen := func(sound: StringName) -> void: heard.append(sound)
	EventBus.sound_requested.connect(listen)
	player.walk_steps(Player.STEP_DISTANCE * 3.5)
	assert_eq(heard.count(&"pas"), 3)
	heard.clear()
	player.crouched = true
	player.walk_steps(Player.STEP_DISTANCE * 3.5)
	assert_eq(heard.count(&"pas"), 0, "accroupi, on ne s'entend pas")
	EventBus.sound_requested.disconnect(listen)


func _player_of(bus: StringName) -> AudioStreamPlayer:
	var players := _players_on(bus)
	return players[0] if not players.is_empty() else null


func _players_on(bus: StringName) -> Array[AudioStreamPlayer]:
	var found: Array[AudioStreamPlayer] = []
	for node: Node in AudioManager.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		if player.playing and player.bus == bus:
			found.append(player)
	return found
