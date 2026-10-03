extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")

var _config: GameConfig
var _state: GameState
var _merge: MergeSystem


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	_state = rig["state"]
	_merge = MergeSystem.new()
	autofree(_merge)
	_merge.setup(_state, rig["spawner"], rig["board"])
	var progress := ProgressSystem.new()
	autofree(progress)
	progress.setup(_state, _config, _merge)


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
