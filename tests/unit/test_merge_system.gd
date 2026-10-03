extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")

var _config: GameConfig
var _board: Board
var _state: GameState
var _spawner: PieceSpawner
var _merge: MergeSystem


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	_board = rig["board"]
	_state = rig["state"]
	_spawner = rig["spawner"]
	_merge = MergeSystem.new()
	autofree(_merge)
	_merge.setup(_state, _spawner, _board)


func _piece(level: int, pos: Vector2) -> Piece:
	return _spawner.spawn(_config.piece_catalog.get_by_level(level), pos, Piece.State.ACTIVE)


func test_same_data_consumes_both_and_queues() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	var b: Piece = _piece(1, Vector2(120.0, 500.0))
	_merge.handle_contact(a, b)
	assert_true(a.is_consumed())
	assert_true(b.is_consumed())
	assert_eq(_merge.get_pending_count(), 1)


func test_different_data_does_nothing() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	var b: Piece = _piece(2, Vector2(130.0, 500.0))
	_merge.handle_contact(a, b)
	assert_false(a.is_consumed())
	assert_false(b.is_consumed())
	assert_eq(_merge.get_pending_count(), 0)


func test_contact_with_itself_is_ignored() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	_merge.handle_contact(a, a)
	assert_false(a.is_consumed())
	assert_eq(_merge.get_pending_count(), 0)


func test_first_contact_wins_among_three() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	var b: Piece = _piece(1, Vector2(120.0, 500.0))
	var c: Piece = _piece(1, Vector2(140.0, 500.0))
	_merge.handle_contact(a, b)
	_merge.handle_contact(b, c)
	assert_eq(_merge.get_pending_count(), 1)
	assert_false(c.is_consumed(), "C queda libre")


func test_contact_ignored_when_not_playing() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	var b: Piece = _piece(1, Vector2(120.0, 500.0))
	_state.set_game_over()
	_merge.handle_contact(a, b)
	assert_eq(_merge.get_pending_count(), 0)
	assert_false(a.is_consumed())


func test_tick_replaces_pair_with_next_level_at_midpoint() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	var b: Piece = _piece(1, Vector2(140.0, 500.0))
	watch_signals(_merge)
	_merge.handle_contact(a, b)
	_merge.tick()
	assert_eq(_merge.get_pending_count(), 0)
	var pieces: Array[Piece] = _board.get_pieces()
	assert_eq(pieces.size(), 1, "A y B eliminadas, una pieza nueva")
	assert_eq(pieces[0].data.level, 2)
	assert_eq(pieces[0].state, Piece.State.ACTIVE)
	assert_eq(pieces[0].position, Vector2(120.0, 500.0))
	assert_signal_emit_count(_merge, "pieces_merged", 1)
	assert_signal_emitted_with_parameters(_merge, "pieces_merged",
			[_config.piece_catalog.get_by_level(1), _config.piece_catalog.get_by_level(2),
			Vector2(120.0, 500.0)])


func test_new_piece_is_clamped_next_to_wall() -> void:
	var a: Piece = _piece(1, Vector2(16.0, 500.0))
	var b: Piece = _piece(1, Vector2(16.0, 520.0))
	_merge.handle_contact(a, b)
	_merge.tick()
	var radius: float = _config.piece_catalog.get_by_level(2).radius
	assert_gte(_board.get_pieces()[0].position.x, radius)


func test_max_level_merge_creates_nothing() -> void:
	var top: int = _config.piece_catalog.get_max_level()
	var a: Piece = _piece(top, Vector2(150.0, 500.0))
	var b: Piece = _piece(top, Vector2(250.0, 500.0))
	watch_signals(_merge)
	_merge.handle_contact(a, b)
	_merge.tick()
	assert_eq(_board.get_pieces().size(), 0)
	assert_signal_emit_count(_merge, "max_level_merged", 1)
	assert_signal_not_emitted(_merge, "pieces_merged")


func test_rest_of_queue_is_dropped_when_game_stops_midway() -> void:
	var top: int = _config.piece_catalog.get_max_level()
	var first_a: Piece = _piece(top, Vector2(150.0, 500.0))
	var first_b: Piece = _piece(top, Vector2(250.0, 500.0))
	var second_a: Piece = _piece(1, Vector2(100.0, 300.0))
	var second_b: Piece = _piece(1, Vector2(120.0, 300.0))
	_merge.max_level_merged.connect(func(_s: PieceData, _p: Vector2) -> void: _state.set_victory())
	_merge.handle_contact(first_a, first_b)
	_merge.handle_contact(second_a, second_b)
	_merge.tick()
	assert_eq(_merge.get_pending_count(), 0)
	assert_eq(_board.get_pieces().size(), 2, "el segundo par no se resolvió")


func test_reset_clears_queue() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	var b: Piece = _piece(1, Vector2(120.0, 500.0))
	_merge.handle_contact(a, b)
	_merge.reset()
	assert_eq(_merge.get_pending_count(), 0)
	_merge.tick()
	assert_eq(_board.get_pieces().size(), 2, "nada se resolvió")


func test_register_piece_connects_contact_signal() -> void:
	var a: Piece = _piece(1, Vector2(100.0, 500.0))
	var b: Piece = _piece(1, Vector2(120.0, 500.0))
	_merge.register_piece(a)
	a.contact_detected.emit(a, b)
	assert_eq(_merge.get_pending_count(), 1)
