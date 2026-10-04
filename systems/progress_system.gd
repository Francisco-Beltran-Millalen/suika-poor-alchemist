class_name ProgressSystem
extends Node
## Traduce fusiones en progreso: suma puntos y declara la victoria.

## Puntos sumados por una fusión y dónde ocurrió (para el texto flotante).
## Así la presentación no duplica la regla de puntuación.
signal points_awarded(amount: int, position: Vector2)

var _state: GameState
var _config: GameConfig


func setup(state: GameState, config: GameConfig, merge_system: MergeSystem) -> void:
	_state = state
	_config = config
	merge_system.pieces_merged.connect(_on_merge_system_pieces_merged)
	merge_system.max_level_merged.connect(_on_merge_system_max_level_merged)


func _on_merge_system_pieces_merged(_source: PieceData, result: PieceData, merge_position: Vector2) -> void:
	# `add_score` ignora los puntos fuera de `PLAYING`: tampoco se anuncian.
	if not _state.is_playing() or result.score_value <= 0:
		return
	_state.add_score(result.score_value)
	points_awarded.emit(result.score_value, merge_position)


func _on_merge_system_max_level_merged(_source: PieceData, merge_position: Vector2) -> void:
	# Se anuncia antes de `set_victory()`: después ya no está en `PLAYING`.
	if _state.is_playing() and _config.victory_bonus > 0:
		_state.add_score(_config.victory_bonus)
		points_awarded.emit(_config.victory_bonus, merge_position)
	_state.set_victory()
