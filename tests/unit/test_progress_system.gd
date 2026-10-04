extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")

var _config: GameConfig
var _state: GameState
var _merge: MergeSystem
var _progress: ProgressSystem


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	_state = rig["state"]
	_merge = MergeSystem.new()
	autofree(_merge)
	_merge.setup(_state, rig["spawner"], rig["board"])
	_progress = ProgressSystem.new()
	autofree(_progress)
	_progress.setup(_state, _config, _merge)


func test_pieces_merged_adds_result_score() -> void:
	var source: PieceData = _config.piece_catalog.get_by_level(2)
	var result: PieceData = _config.piece_catalog.get_by_level(3)
	_merge.pieces_merged.emit(source, result, Vector2.ZERO)
	assert_eq(_state.get_score(), result.score_value)
	_merge.pieces_merged.emit(source, result, Vector2.ZERO)
	assert_eq(_state.get_score(), 2 * result.score_value)


func test_max_level_merged_adds_bonus_and_wins() -> void:
	var top: PieceData = _config.piece_catalog.get_by_level(_config.piece_catalog.get_max_level())
	_merge.max_level_merged.emit(top, Vector2.ZERO)
	assert_eq(_state.get_score(), _config.victory_bonus)
	assert_eq(_state.get_status(), GameState.Status.VICTORY)


func test_points_awarded_carries_result_score_and_position() -> void:
	watch_signals(_progress)
	var source: PieceData = _config.piece_catalog.get_by_level(2)
	var result: PieceData = _config.piece_catalog.get_by_level(3)
	_merge.pieces_merged.emit(source, result, Vector2(120.0, 340.0))
	assert_signal_emitted_with_parameters(_progress, "points_awarded",
			[result.score_value, Vector2(120.0, 340.0)])


func test_points_awarded_on_max_merge_carries_victory_bonus() -> void:
	watch_signals(_progress)
	var top: PieceData = _config.piece_catalog.get_by_level(_config.piece_catalog.get_max_level())
	_merge.max_level_merged.emit(top, Vector2(200.0, 500.0))
	assert_signal_emitted_with_parameters(_progress, "points_awarded",
			[_config.victory_bonus, Vector2(200.0, 500.0)])
	assert_eq(_state.get_status(), GameState.Status.VICTORY)


func test_points_awarded_not_emitted_outside_playing() -> void:
	_state.set_game_over()
	watch_signals(_progress)
	var source: PieceData = _config.piece_catalog.get_by_level(2)
	var top: PieceData = _config.piece_catalog.get_by_level(_config.piece_catalog.get_max_level())
	_merge.pieces_merged.emit(source, _config.piece_catalog.get_by_level(3), Vector2.ZERO)
	_merge.max_level_merged.emit(top, Vector2.ZERO)
	assert_signal_not_emitted(_progress, "points_awarded")
	assert_eq(_state.get_score(), 0)
