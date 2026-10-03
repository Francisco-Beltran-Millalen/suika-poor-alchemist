class_name DangerSystem
extends Node
## Regla de derrota: una pieza `ACTIVE` sobre la línea durante `game_over_delay`.

## Progreso hacia el Game Over, de 0 a 1.
signal danger_changed(ratio: float)

var _state: GameState
var _danger_zone: DangerZone
var _config: GameConfig
# Segundos que cada pieza lleva sobre la línea, por `get_instance_id()`.
var _timers: Dictionary = {}
var _ratio: float = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


func setup(state: GameState, danger_zone: DangerZone, config: GameConfig) -> void:
	_state = state
	_danger_zone = danger_zone
	_config = config


func tick(delta: float) -> void:
	if not _state.is_playing():
		return
	var updated: Dictionary = {}
	var longest: float = 0.0
	for piece: Piece in _danger_zone.get_pieces_inside():
		if piece.state != Piece.State.ACTIVE:
			continue
		var id: int = piece.get_instance_id()
		var elapsed: float = float(_timers.get(id, 0.0)) + delta
		updated[id] = elapsed
		longest = maxf(longest, elapsed)
	# Las piezas que salieron no están en `updated`: su contador se reinicia.
	_timers = updated
	var ratio: float = 1.0 if _config.game_over_delay <= 0.0 and not updated.is_empty() \
			else clampf(longest / maxf(_config.game_over_delay, 0.0001), 0.0, 1.0)
	_set_ratio(ratio)
	if not updated.is_empty() and longest >= _config.game_over_delay:
		_state.set_game_over()


## Borra los contadores y emite `danger_changed(0)` siempre.
func reset() -> void:
	_timers.clear()
	_ratio = 0.0
	danger_changed.emit(0.0)


func _set_ratio(ratio: float) -> void:
	if is_equal_approx(ratio, _ratio):
		return
	_ratio = ratio
	danger_changed.emit(_ratio)
