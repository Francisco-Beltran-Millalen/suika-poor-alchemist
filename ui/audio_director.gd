class_name AudioDirector
extends Node
## Reproduce el sonido de cada evento y la música del taller.
##
## Solo observa señales de la simulación. Con un `AudioStream` nulo no suena
## nada y nada falla. Debe procesar también en pausa (`PROCESS_MODE_ALWAYS`).

const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const SFX_VOICES: int = 8
const MUSIC_VOLUME_DB: float = -8.0
const MUSIC_DUCKED_DB: float = -20.0
## Tono de la fusión: baja con el nivel (las piezas grandes suenan graves).
const MERGE_PITCH_BASE: float = 1.5
const MERGE_PITCH_STEP: float = 0.1
const MERGE_PITCH_MIN: float = 0.6
## Volumen mínimo del bucle de peligro cuando el ratio es casi 0.
const DANGER_MIN_DB: float = -30.0

var _sounds: SoundSet
var _music_player: AudioStreamPlayer
var _danger_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _last_merge_stream: AudioStream
var _danger_active: bool = false
var _is_paused: bool = false
var _is_ducked: bool = false


func setup(state: GameState, drop_system: DropSystem, merge_system: MergeSystem,
		danger_system: DangerSystem, sounds: SoundSet) -> void:
	_sounds = sounds if sounds != null else SoundSet.new()
	_build_players()
	drop_system.piece_dropped.connect(_on_drop_system_piece_dropped)
	merge_system.pieces_merged.connect(_on_merge_system_pieces_merged)
	danger_system.danger_changed.connect(_on_danger_system_danger_changed)
	state.status_changed.connect(_on_state_status_changed)
	_music_player.stream = _sounds.music
	_apply_music_volume()
	if _sounds.music != null:
		_music_player.play()


## Silencia o restaura el bus Master.
func toggle_mute() -> void:
	AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


## Pausa el bucle de peligro y baja la música; `false` lo restaura.
func set_paused(paused: bool) -> void:
	_is_paused = paused
	_danger_player.stream_paused = paused
	_apply_music_volume()


## Sonido de los botones de la interfaz.
func play_ui_click() -> void:
	_play_sfx(_sounds.ui_click)


## Último stream elegido para una fusión (`null` si ninguno).
func get_last_merge_stream() -> AudioStream:
	return _last_merge_stream


## Indica si el bucle de peligro está sonando.
func is_danger_playing() -> bool:
	return _danger_active


func _build_players() -> void:
	if _music_player != null:
		return
	_music_player = _make_player(MUSIC_BUS)
	_danger_player = _make_player(SFX_BUS)
	for i: int in SFX_VOICES:
		_sfx_players.append(_make_player(SFX_BUS))


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


# Varias voces en rotación: las cascadas no cortan sonidos anteriores.
func _play_sfx(stream: AudioStream, pitch: float = 1.0) -> void:
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func _apply_music_volume() -> void:
	_music_player.volume_db = MUSIC_DUCKED_DB if (_is_ducked or _is_paused) else MUSIC_VOLUME_DB


func _set_danger(ratio: float) -> void:
	if ratio <= 0.0 or _sounds.danger_loop == null:
		_danger_active = false
		_danger_player.stop()
		return
	_danger_player.volume_db = maxf(linear_to_db(clampf(ratio, 0.0, 1.0)), DANGER_MIN_DB)
	if not _danger_active:
		_danger_active = true
		_danger_player.stream = _sounds.danger_loop
		_danger_player.play()


func _on_drop_system_piece_dropped(_piece: Piece) -> void:
	_play_sfx(_sounds.drop)


func _on_merge_system_pieces_merged(_source: PieceData, result: PieceData, _position: Vector2) -> void:
	var stream: AudioStream = _sounds.merge
	var pitch: float = maxf(MERGE_PITCH_BASE - MERGE_PITCH_STEP * result.level, MERGE_PITCH_MIN)
	if PieceVisual.is_high_tier(result) and _sounds.merge_high != null:
		stream = _sounds.merge_high
		pitch = 1.0
	_last_merge_stream = stream
	_play_sfx(stream, pitch)


func _on_danger_system_danger_changed(ratio: float) -> void:
	_set_danger(ratio)


func _on_state_status_changed(status: GameState.Status) -> void:
	_is_ducked = status == GameState.Status.GAME_OVER or status == GameState.Status.VICTORY
	_apply_music_volume()
	match status:
		GameState.Status.GAME_OVER:
			_set_danger(0.0)
			_play_sfx(_sounds.game_over)
		GameState.Status.VICTORY:
			_set_danger(0.0)
			_play_sfx(_sounds.victory)
