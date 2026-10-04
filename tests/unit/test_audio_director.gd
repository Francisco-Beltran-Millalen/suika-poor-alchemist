extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")

var _config: GameConfig
var _state: GameState
var _drop: DropSystem
var _merge: MergeSystem
var _danger: DangerSystem
var _director: AudioDirector


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	_state = rig["state"]
	_drop = DropSystem.new()
	autofree(_drop)
	_drop.setup(_state, PieceGenerator.new(_config.piece_catalog, _config.spawn_strategy, 1),
			rig["spawner"], rig["board"], _config)
	_merge = MergeSystem.new()
	autofree(_merge)
	_merge.setup(_state, rig["spawner"], rig["board"])
	_danger = DangerSystem.new()
	autofree(_danger)
	_danger.setup(_state, (rig["board"] as Board).danger_zone, _config)
	_director = AudioDirector.new()
	add_child_autofree(_director)


func after_each() -> void:
	AudioServer.set_bus_mute(0, false)


func _generator_set() -> SoundSet:
	var sounds := SoundSet.new()
	for property: String in ["drop", "merge", "merge_high", "danger_loop", "game_over",
			"victory", "ui_click", "music"]:
		sounds.set(property, AudioStreamGenerator.new())
	return sounds


func _piece(level: int) -> PieceData:
	return _config.piece_catalog.get_by_level(level)


func _high_piece() -> PieceData:
	var data: PieceData = _piece(6)
	data.glow_strength = PieceVisual.PULSE_MIN_GLOW
	return data


func _low_piece() -> PieceData:
	var data: PieceData = _piece(2)
	data.glow_strength = 0.0
	return data


func test_all_null_sound_set_never_fails() -> void:
	_director.setup(_state, _drop, _merge, _danger, SoundSet.new())
	_drop.reset()
	_drop.request_drop()
	_merge.pieces_merged.emit(_piece(1), _low_piece(), Vector2.ZERO)
	_merge.pieces_merged.emit(_piece(5), _high_piece(), Vector2.ZERO)
	_danger.danger_changed.emit(0.5)
	_danger.danger_changed.emit(0.0)
	_director.play_ui_click()
	_state.set_game_over()
	_state.reset()
	_state.start()
	_state.set_victory()
	assert_null(_director.get_last_merge_stream())
	assert_false(_director.is_danger_playing())


func test_null_sound_set_is_accepted() -> void:
	_director.setup(_state, _drop, _merge, _danger, null)
	_merge.pieces_merged.emit(_piece(1), _low_piece(), Vector2.ZERO)
	assert_null(_director.get_last_merge_stream())


func test_high_merge_uses_merge_high_and_low_uses_merge() -> void:
	var sounds: SoundSet = _generator_set()
	_director.setup(_state, _drop, _merge, _danger, sounds)
	_merge.pieces_merged.emit(_piece(1), _low_piece(), Vector2.ZERO)
	assert_same(_director.get_last_merge_stream(), sounds.merge)
	_merge.pieces_merged.emit(_piece(5), _high_piece(), Vector2.ZERO)
	assert_same(_director.get_last_merge_stream(), sounds.merge_high)


func test_high_merge_falls_back_to_merge_without_merge_high() -> void:
	var sounds: SoundSet = _generator_set()
	sounds.merge_high = null
	_director.setup(_state, _drop, _merge, _danger, sounds)
	_merge.pieces_merged.emit(_piece(5), _high_piece(), Vector2.ZERO)
	assert_same(_director.get_last_merge_stream(), sounds.merge)


func test_danger_loop_follows_the_ratio() -> void:
	_director.setup(_state, _drop, _merge, _danger, _generator_set())
	_danger.danger_changed.emit(0.5)
	assert_true(_director.is_danger_playing())
	_danger.danger_changed.emit(0.0)
	assert_false(_director.is_danger_playing())


func test_end_of_game_stops_the_danger_loop() -> void:
	_director.setup(_state, _drop, _merge, _danger, _generator_set())
	_danger.danger_changed.emit(0.8)
	_state.set_game_over()
	assert_false(_director.is_danger_playing())


func test_pause_pauses_the_danger_loop_and_restores_it() -> void:
	_director.setup(_state, _drop, _merge, _danger, _generator_set())
	_danger.danger_changed.emit(0.5)
	var danger_player: AudioStreamPlayer = _director.get_child(1) as AudioStreamPlayer
	_director.set_paused(true)
	assert_true(danger_player.stream_paused)
	_director.set_paused(false)
	assert_false(danger_player.stream_paused)


func test_music_is_ducked_in_end_screens_and_restored() -> void:
	_director.setup(_state, _drop, _merge, _danger, _generator_set())
	var music_player: AudioStreamPlayer = _director.get_child(0) as AudioStreamPlayer
	assert_eq(music_player.volume_db, AudioDirector.MUSIC_VOLUME_DB)
	_state.set_game_over()
	assert_eq(music_player.volume_db, AudioDirector.MUSIC_DUCKED_DB)
	_state.reset()
	assert_eq(music_player.volume_db, AudioDirector.MUSIC_VOLUME_DB)


func test_toggle_mute_flips_the_master_bus() -> void:
	_director.setup(_state, _drop, _merge, _danger, SoundSet.new())
	assert_false(AudioServer.is_bus_mute(0))
	_director.toggle_mute()
	assert_true(AudioServer.is_bus_mute(0))
	_director.toggle_mute()
	assert_false(AudioServer.is_bus_mute(0))


func test_music_and_sfx_buses_exist() -> void:
	assert_ne(AudioServer.get_bus_index(AudioDirector.MUSIC_BUS), -1)
	assert_ne(AudioServer.get_bus_index(AudioDirector.SFX_BUS), -1)
