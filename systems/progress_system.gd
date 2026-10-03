class_name ProgressSystem
extends Node
## Traduce fusiones en progreso: suma puntos y declara la victoria.

var _state: GameState
var _config: GameConfig


func setup(state: GameState, config: GameConfig, merge_system: MergeSystem) -> void:
	_state = state
	_config = config
	merge_system.pieces_merged.connect(_on_merge_system_pieces_merged)
	merge_system.max_level_merged.connect(_on_merge_system_max_level_merged)


func _on_merge_system_pieces_merged(_source: PieceData, result: PieceData, _position: Vector2) -> void:
	_state.add_score(result.score_value)


func _on_merge_system_max_level_merged(_source: PieceData, _position: Vector2) -> void:
	_state.add_score(_config.victory_bonus)
	_state.set_victory()
