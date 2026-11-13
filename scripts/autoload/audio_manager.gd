extends Node
## Le son du jeu : bruitages, musique et ambiance, chacun sur son bus (voir
## default_bus_layout.tres), déclenchés par l'EventBus. Les sons sont synthétisés par
## tools/build_sounds.py.
##
## Les réglages de volume passent par les bus (set_volume). Sous un dialogue, la musique se
## tasse par le bus MusicDuck, sans toucher au réglage du joueur sur le bus Music.

const SOUND_PATH := "res://assets/audio/%s.wav"
const BUS_MUSIC := &"Music"
const BUS_DUCK := &"MusicDuck"
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"
const BUS_UI := &"UI"
## Bruitages qui peuvent se chevaucher.
const POOL_SIZE := 10
## Son → bus, volume (dB), nombre de prises (nom_1, nom_2…), variation de hauteur
## (± demi-tons) : un son répété ne sonne jamais deux fois pareil.
const SOUNDS := {
	&"pas": {"bus": BUS_SFX, "volume": -16.0, "takes": 3, "pitch": 1.0},
	&"coup": {"bus": BUS_SFX, "volume": -4.0, "pitch": 1.0},
	&"ko": {"bus": BUS_SFX, "volume": -4.0},
	&"vigile_alerte": {"bus": BUS_SFX, "volume": -6.0},
	&"camera_repere": {"bus": BUS_SFX, "volume": -8.0},
	&"alarme": {"bus": BUS_SFX, "volume": -12.0},
	&"porte": {"bus": BUS_SFX, "volume": -6.0, "pitch": 0.5},
	&"ramassage": {"bus": BUS_SFX, "volume": -8.0},
	&"bombe": {"bus": BUS_SFX, "volume": -8.0},
	&"coupe": {"bus": BUS_SFX, "volume": -6.0},
	&"sirene": {"bus": BUS_SFX, "volume": -14.0},
	&"annonce": {"bus": BUS_SFX, "volume": -10.0},
	&"objectif": {"bus": BUS_UI, "volume": -8.0},
	&"quete": {"bus": BUS_UI, "volume": -6.0},
	&"niveau": {"bus": BUS_UI, "volume": -6.0},
	&"liberation": {"bus": BUS_SFX, "volume": -6.0},
	&"arrestation": {"bus": BUS_SFX, "volume": -6.0},
	&"ui_survol": {"bus": BUS_UI, "volume": -12.0},
	&"ui_valide": {"bus": BUS_UI, "volume": -8.0},
	&"ui_retour": {"bus": BUS_UI, "volume": -8.0},
	&"bulle": {"bus": BUS_UI, "volume": -14.0, "pitch": 1.0},
}
## Les musiques : le régime, la maison, le quartier libre.
const MUSIC := {&"regime": "musique_regime", &"maison": "musique_maison", &"libre": "musique_libre"}
const AMBIENCES := {&"ville": "ambiance_ville"}
const SILENT_DB := -60.0
const DUCK_DB := -8.0
const DUCK_SECONDS := 0.3
const AMBIENCE_FADE_SECONDS := 1.0
## Une prise répétée change un peu de volume (± dB).
const VOLUME_SPREAD_DB := 1.5

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next_player := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_track := &""
var _ambience := AudioStreamPlayer.new()
var _ambience_track := &""
var _duck_tween: Tween


func _ready() -> void:
	# Les menus mettent le jeu en pause : leurs sons doivent jouer quand même.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for sound: StringName in SOUNDS:
		_streams[sound] = _make_stream(sound, SOUNDS[sound])
	for index: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % index
		add_child(player)
		_pool.append(player)
	for index: int in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = BUS_MUSIC
		player.volume_db = SILENT_DB
		add_child(player)
		_music_players.append(player)
	_ambience.name = "Ambience"
	_ambience.bus = BUS_AMBIENCE
	add_child(_ambience)
	_connect_events()


## Joue un bruitage ; un son inconnu est signalé et rien ne se passe.
func play(sound: StringName) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		push_error("Son inconnu : %s" % sound)
		return
	var player := _pool[_next_player]
	_next_player = (_next_player + 1) % POOL_SIZE
	player.stream = stream
	player.bus = SOUNDS[sound]["bus"]
	player.volume_db = SOUNDS[sound].get("volume", 0.0)
	player.play()


## Passe à la musique `track` (&"" : le silence) en fondu enchaîné de `seconds` secondes.
func play_music(track: StringName, seconds: float) -> void:
	if track == _music_track:
		return
	_music_track = track
	var outgoing := _music_players[0]
	var incoming := _music_players[1]
	_music_players.reverse()
	if not track.is_empty():
		incoming.stream = load(SOUND_PATH % MUSIC[track])
		incoming.volume_db = SILENT_DB if seconds > 0.0 else 0.0
		incoming.play()
	if seconds <= 0.0:
		outgoing.stop()
		return
	var fade := create_tween().set_parallel(true)
	fade.tween_property(outgoing, ^"volume_db", SILENT_DB, seconds)
	if not track.is_empty():
		fade.tween_property(incoming, ^"volume_db", 0.0, seconds)
	fade.chain().tween_callback(outgoing.stop)


func music() -> StringName:
	return _music_track


## L'ambiance du lieu (&"" : aucune).
func play_ambience(track: StringName) -> void:
	if track == _ambience_track:
		return
	_ambience_track = track
	if track.is_empty():
		_ambience.stop()
		return
	_ambience.stream = load(SOUND_PATH % AMBIENCES[track])
	_ambience.volume_db = SILENT_DB
	_ambience.play()
	create_tween().tween_property(_ambience, ^"volume_db", 0.0, AMBIENCE_FADE_SECONDS)


func ambience() -> StringName:
	return _ambience_track


## Volume d'un bus, de 0 (muet) à 1 ; la courbe est au carré, comme l'oreille l'entend.
func set_volume(bus: StringName, value: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index == -1:
		push_error("Bus audio inconnu : %s" % bus)
		return
	var level := clampf(value, 0.0, 1.0)
	AudioServer.set_bus_mute(index, level <= 0.0)
	if level > 0.0:
		AudioServer.set_bus_volume_linear(index, level * level)


func _make_stream(sound: StringName, spec: Dictionary) -> AudioStream:
	var takes: int = spec.get("takes", 1)
	var pitch: float = spec.get("pitch", 0.0)
	if takes == 1 and is_zero_approx(pitch):
		return load(SOUND_PATH % sound)
	var randomizer := AudioStreamRandomizer.new()
	for take: int in takes:
		var file := String(sound) if takes == 1 else "%s_%d" % [sound, take + 1]
		randomizer.add_stream(-1, load(SOUND_PATH % file))
	randomizer.random_pitch_semitones = pitch
	randomizer.random_volume_offset_db = VOLUME_SPREAD_DB
	return randomizer


func _connect_events() -> void:
	EventBus.sound_requested.connect(play)
	EventBus.music_requested.connect(play_music)
	EventBus.ambience_requested.connect(play_ambience)
	EventBus.enemy_knocked_out.connect(func(_enemy: String) -> void: play(&"ko"))
	EventBus.curfew_changed.connect(_on_curfew_changed)
	EventBus.notified.connect(_on_notified)
	EventBus.quest_step_completed.connect(_on_step_completed)
	EventBus.quest_completed.connect(func(_quest: String) -> void: play(&"quete"))
	EventBus.leveled_up.connect(func(_level: int) -> void: play(&"niveau"))
	EventBus.zone_liberated.connect(func(_zone: String) -> void: play(&"liberation"))
	EventBus.player_downed.connect(func() -> void: play(&"arrestation"))
	EventBus.travel_requested.connect(func(_target: String) -> void: play(&"porte"))
	EventBus.dialogue_requested.connect(func(_file: String, _cue: String) -> void: _duck(true))
	EventBus.dialogue_ended.connect(func(_file: String) -> void: _duck(false))


func _on_curfew_changed(active: bool) -> void:
	if active:
		play(&"sirene")


func _on_notified(text_key: String) -> void:
	if text_key == "CURFEW_WARNING":
		play(&"annonce")


# La dernière étape d'une quête a son propre son (« quete ») : on attend la fin de l'image
# pour savoir si la quête vient de se terminer.
func _on_step_completed(quest_id: String, _step_id: String) -> void:
	_play_step_sound.call_deferred(quest_id)


func _play_step_sound(quest_id: String) -> void:
	if GameState.quests.is_active(quest_id):
		play(&"objectif")


# Sous un dialogue, la musique fait un pas en arrière.
func _duck(active: bool) -> void:
	var index := AudioServer.get_bus_index(BUS_DUCK)
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(index, db),
		AudioServer.get_bus_volume_db(index),
		DUCK_DB if active else 0.0,
		DUCK_SECONDS
	)
