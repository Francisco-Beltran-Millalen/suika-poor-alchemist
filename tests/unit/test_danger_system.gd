extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const StubDangerZone := preload("res://tests/helpers/stub_danger_zone.gd")

var _config: GameConfig
var _state: GameState
var _zone: DangerZone
var _danger: DangerSystem
var _piece: Piece


func before_each() -> void:
	_config = DataFactory.make_config()
	_state = GameState.new()
	_state.start()
	_zone = StubDangerZone.new()
	autofree(_zone)
	_danger = DangerSystem.new()
	autofree(_danger)
	_danger.setup(_state, _zone, _config)
	_piece = DataFactory.make_piece(_config.piece_catalog.get_by_level(1), Piece.State.ACTIVE)
	add_child_autofree(_piece)
	_zone.set("pieces", [_piece] as Array[Piece])


func _set_inside(inside: Array[Piece]) -> void:
	_zone.set("pieces", inside)


func test_active_piece_inside_triggers_game_over_after_delay() -> void:
	watch_signals(_danger)
	_danger.tick(0.5)
	assert_true(_state.is_playing())
	assert_signal_emitted_with_parameters(_danger, "danger_changed", [0.5])
	_danger.tick(0.5)
	assert_eq(_state.get_status(), GameState.Status.GAME_OVER)
	assert_signal_emitted_with_parameters(_danger, "danger_changed", [1.0])


func test_dropping_piece_is_exempt() -> void:
	_piece.state = Piece.State.DROPPING
	_danger.tick(5.0)
	assert_true(_state.is_playing())


func test_consumed_piece_is_exempt() -> void:
	_piece.consume()
	_danger.tick(5.0)
	assert_true(_state.is_playing())


func test_timer_restarts_when_piece_leaves_and_returns() -> void:
	_danger.tick(0.8)
	_set_inside([] as Array[Piece])
	_danger.tick(0.1)
	_set_inside([_piece] as Array[Piece])
	_danger.tick(0.5)
	assert_true(_state.is_playing(), "el contador empezó de cero")
	_danger.tick(0.5)
	assert_eq(_state.get_status(), GameState.Status.GAME_OVER)


func test_danger_changed_only_when_value_changes() -> void:
	_danger.tick(0.25)
	watch_signals(_danger)
	_danger.tick(0.0)
	assert_signal_not_emitted(_danger, "danger_changed")


func test_leaving_the_zone_emits_zero() -> void:
	_danger.tick(0.5)
	watch_signals(_danger)
	_set_inside([] as Array[Piece])
	_danger.tick(0.1)
	assert_signal_emitted_with_parameters(_danger, "danger_changed", [0.0])


func test_tick_does_nothing_when_not_playing() -> void:
	_state.set_game_over()
	watch_signals(_danger)
	_danger.tick(5.0)
	assert_signal_not_emitted(_danger, "danger_changed")
	assert_eq(_state.get_status(), GameState.Status.GAME_OVER)


func test_reset_clears_timers_and_emits_zero() -> void:
	_danger.tick(0.9)
	watch_signals(_danger)
	_danger.reset()
	assert_signal_emitted_with_parameters(_danger, "danger_changed", [0.0])
	_danger.tick(0.5)
	assert_true(_state.is_playing(), "tras reset el contador empieza de cero")
