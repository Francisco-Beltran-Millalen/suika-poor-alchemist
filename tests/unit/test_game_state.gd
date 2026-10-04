extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")

var _state: GameState
var _catalog: PieceCatalog


func before_each() -> void:
	_state = GameState.new()
	_catalog = DataFactory.make_catalog()


func _to_playing() -> void:
	_state.start()


func test_initial_status_is_ready() -> void:
	assert_true(_state.is_ready())
	assert_eq(_state.get_status(), GameState.Status.READY)
	assert_false(_state.is_playing())
	assert_false(_state.is_finished())


func test_valid_transitions_emit_once() -> void:
	watch_signals(_state)
	assert_true(_state.start())
	assert_signal_emit_count(_state, "status_changed", 1)
	assert_true(_state.is_playing())
	assert_true(_state.set_game_over())
	assert_signal_emit_count(_state, "status_changed", 2)
	assert_eq(_state.get_status(), GameState.Status.GAME_OVER)
	assert_true(_state.is_finished())


func test_victory_transition() -> void:
	_to_playing()
	watch_signals(_state)
	assert_true(_state.set_victory())
	assert_signal_emit_count(_state, "status_changed", 1)
	assert_eq(_state.get_status(), GameState.Status.VICTORY)
	assert_true(_state.is_finished())


func test_invalid_transitions_return_false_and_do_not_emit() -> void:
	# READY: no se puede perder ni ganar.
	watch_signals(_state)
	assert_false(_state.set_game_over())
	assert_false(_state.set_victory())
	# PLAYING: no se puede volver a empezar.
	_to_playing()
	assert_false(_state.start())
	# Estados finales: no hay salida salvo reset().
	_state.set_game_over()
	assert_false(_state.start())
	assert_false(_state.set_game_over())
	assert_false(_state.set_victory())
	assert_signal_emit_count(_state, "status_changed", 2, "solo start y set_game_over")


func test_add_score_only_while_playing() -> void:
	watch_signals(_state)
	_state.add_score(5)
	assert_eq(_state.get_score(), 0, "ignorado en READY")
	assert_signal_not_emitted(_state, "score_changed")
	_to_playing()
	_state.add_score(5)
	_state.add_score(3)
	assert_eq(_state.get_score(), 8)
	assert_signal_emit_count(_state, "score_changed", 2)
	_state.set_game_over()
	_state.add_score(10)
	assert_eq(_state.get_score(), 8, "ignorado tras el fin")


func test_add_score_zero_does_not_emit() -> void:
	_to_playing()
	watch_signals(_state)
	_state.add_score(0)
	assert_signal_not_emitted(_state, "score_changed")


func test_advance_queue_returns_outgoing_and_shifts() -> void:
	var a: PieceData = _catalog.get_by_level(1)
	var b: PieceData = _catalog.get_by_level(2)
	var c: PieceData = _catalog.get_by_level(3)
	_state.set_queue(a, b)
	watch_signals(_state)
	var outgoing: PieceData = _state.advance_queue(c)
	assert_same(outgoing, a)
	assert_same(_state.get_current_piece(), b)
	assert_same(_state.get_next_piece(), c)
	assert_signal_emit_count(_state, "current_piece_changed", 1)
	assert_signal_emit_count(_state, "next_piece_changed", 1)


func test_queue_signals_emit_even_with_same_resource() -> void:
	var a: PieceData = _catalog.get_by_level(1)
	_state.set_queue(a, a)
	watch_signals(_state)
	_state.advance_queue(a)
	assert_signal_emit_count(_state, "current_piece_changed", 1)
	assert_signal_emit_count(_state, "next_piece_changed", 1)
	_state.set_queue(a, a)
	assert_signal_emit_count(_state, "current_piece_changed", 2)
	assert_signal_emit_count(_state, "next_piece_changed", 2)


func test_reset_clears_everything_and_emits_all_signals() -> void:
	_to_playing()
	_state.add_score(7)
	_state.set_queue(_catalog.get_by_level(1), _catalog.get_by_level(2))
	_state.set_game_over()
	watch_signals(_state)
	_state.reset()
	assert_eq(_state.get_score(), 0)
	assert_null(_state.get_current_piece())
	assert_null(_state.get_next_piece())
	assert_eq(_state.get_status(), GameState.Status.READY)
	assert_signal_emit_count(_state, "score_changed", 1)
	assert_signal_emit_count(_state, "current_piece_changed", 1)
	assert_signal_emit_count(_state, "next_piece_changed", 1)
	assert_signal_emit_count(_state, "status_changed", 1)
	assert_signal_emitted_with_parameters(_state, "current_piece_changed", [null])


func test_reset_emits_even_when_already_clean() -> void:
	watch_signals(_state)
	_state.reset()
	assert_signal_emit_count(_state, "score_changed", 1)
	assert_signal_emit_count(_state, "status_changed", 1)


func test_debug_set_current_replaces_current_only() -> void:
	var first: PieceData = _catalog.get_by_level(1)
	var second: PieceData = _catalog.get_by_level(2)
	var replacement: PieceData = _catalog.get_by_level(4)
	_state.set_queue(first, second)
	watch_signals(_state)
	_state.debug_set_current(replacement)
	assert_same(_state.get_current_piece(), replacement)
	assert_same(_state.get_next_piece(), second, "el PRÓXIMO no cambia")
	assert_signal_emit_count(_state, "current_piece_changed", 1)
	assert_signal_not_emitted(_state, "next_piece_changed")
