extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")
const FixedSpawnStrategy := preload("res://tests/helpers/fixed_spawn_strategy.gd")

var _config: GameConfig
var _board: Board
var _state: GameState
var _drop: DropSystem
var _fixed: FixedSpawnStrategy


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	_board = rig["board"]
	_state = rig["state"]
	_fixed = FixedSpawnStrategy.new()
	_fixed.level = 2
	var generator := PieceGenerator.new(_config.piece_catalog, _fixed, _config.rng_seed)
	_drop = DropSystem.new()
	autofree(_drop)
	_drop.setup(_state, generator, rig["spawner"], _board, _config)
	_drop.reset()


func _radius(level: int) -> float:
	return _config.piece_catalog.get_by_level(level).radius


func test_cannot_drop_when_not_playing() -> void:
	_state.reset()
	assert_false(_drop.request_drop(), "READY")
	_drop.reset()
	_state.start()
	_state.set_game_over()
	assert_false(_drop.request_drop(), "GAME_OVER")
	assert_eq(_board.get_pieces().size(), 0)


func test_drop_creates_dropping_piece_and_advances_queue() -> void:
	_fixed.level = 3
	watch_signals(_drop)
	_drop.request_aim_step(0.0, 0.0)
	var expected: float = _board.clamp_drop_x(_config.container_width / 2.0, _radius(2))
	assert_true(_drop.request_drop())
	var pieces: Array[Piece] = _board.get_pieces()
	assert_eq(pieces.size(), 1)
	assert_eq(pieces[0].position, Vector2(expected, _config.spawn_y))
	assert_eq(pieces[0].state, Piece.State.DROPPING)
	assert_eq(pieces[0].data.level, 2, "suelta el ACTUAL")
	assert_eq(_state.get_next_piece().level, 3, "se generó un PRÓXIMO nuevo")
	assert_signal_emitted(_drop, "piece_dropped")


func test_cooldown_blocks_second_drop_until_tick() -> void:
	assert_true(_drop.request_drop())
	assert_false(_drop.request_drop(), "dentro del cooldown")
	assert_false(_drop.is_drop_ready())
	_drop.tick(0.5)
	assert_true(_drop.is_drop_ready())
	assert_true(_drop.request_drop())
	assert_eq(_board.get_pieces().size(), 2)


func test_drop_ready_changed_at_start_and_end_of_cooldown() -> void:
	watch_signals(_drop)
	_drop.request_drop()
	assert_signal_emitted_with_parameters(_drop, "drop_ready_changed", [false])
	_drop.tick(0.2)
	assert_signal_emit_count(_drop, "drop_ready_changed", 1, "aún en cooldown")
	_drop.tick(0.3)
	assert_signal_emit_count(_drop, "drop_ready_changed", 2)
	assert_signal_emitted_with_parameters(_drop, "drop_ready_changed", [true])


func test_aim_is_clamped_by_current_radius() -> void:
	_drop.request_aim_global(-1000.0)
	assert_eq(_drop.get_aim_x(), _radius(2))
	_drop.request_aim_global(5000.0)
	assert_eq(_drop.get_aim_x(), _config.container_width - _radius(2))


func test_aim_is_reclamped_when_current_changes_and_recovered() -> void:
	_state.set_queue(_config.piece_catalog.get_by_level(1), _config.piece_catalog.get_by_level(2))
	_drop.request_aim_global(30.0)
	assert_eq(_drop.get_aim_x(), 30.0)
	watch_signals(_drop)
	_state.set_queue(_config.piece_catalog.get_by_level(5), _config.piece_catalog.get_by_level(2))
	assert_eq(_drop.get_aim_x(), _radius(5), "limitado por la pieza grande")
	assert_signal_emitted_with_parameters(_drop, "aim_changed", [_radius(5)])
	_state.set_queue(_config.piece_catalog.get_by_level(1), _config.piece_catalog.get_by_level(2))
	assert_eq(_drop.get_aim_x(), 30.0, "se recupera la X original")


func test_null_current_piece_is_handled() -> void:
	_drop.request_aim_global(30.0)
	_state.reset()
	assert_eq(_drop.get_aim_x(), _config.container_width / 2.0)
	assert_false(_drop.request_drop())


func test_aim_step_moves_by_speed() -> void:
	var start: float = _drop.get_aim_x()
	_drop.request_aim_step(1.0, 0.1)
	assert_almost_eq(_drop.get_aim_x(), start + 60.0, 0.001)
	_drop.request_aim_step(-1.0, 0.1)
	assert_almost_eq(_drop.get_aim_x(), start, 0.001)


func test_reset_recenters_aim_and_clears_cooldown() -> void:
	_drop.request_aim_global(50.0)
	_drop.request_drop()
	watch_signals(_drop)
	_drop.reset()
	assert_signal_emitted_with_parameters(_drop, "aim_changed", [_config.container_width / 2.0])
	assert_signal_emitted_with_parameters(_drop, "drop_ready_changed", [true])
	assert_true(_drop.is_drop_ready())
	assert_not_null(_state.get_current_piece())
	assert_not_null(_state.get_next_piece())
