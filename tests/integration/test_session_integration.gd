extends GutTest

const FixedSpawnStrategy := preload("res://tests/helpers/fixed_spawn_strategy.gd")

var _main: Main
var _config: GameConfig


func before_each() -> void:
	_config = (load("res://game/game_config.tres") as GameConfig).duplicate() as GameConfig
	var fixed := FixedSpawnStrategy.new()
	fixed.level = 1
	_config.spawn_strategy = fixed
	_config.rng_seed = 1234
	_main = (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	_main.config = _config
	_main.records_path = ""
	_main.show_title = false
	add_child_autofree(_main)


func after_each() -> void:
	get_tree().paused = false


func _make_titled_main() -> Main:
	var titled := (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	titled.config = _config
	titled.records_path = ""
	titled.show_title = true
	add_child_autofree(titled)
	return titled


func _spawn(level: int, pos: Vector2) -> Piece:
	return _main.get_spawner().spawn(_config.piece_catalog.get_by_level(level), pos, Piece.State.ACTIVE)


func test_merging_two_max_level_pieces_wins() -> void:
	var top: int = _config.piece_catalog.get_max_level()
	_spawn(top, Vector2(140.0, 518.0))
	_spawn(top, Vector2(300.0, 518.0))
	var state: GameState = _main.get_state()
	assert_true(await wait_until(func() -> bool: return state.get_status() == GameState.Status.VICTORY, 3.0),
			"se llega a VICTORY")
	assert_eq(state.get_score(), _config.victory_bonus)
	assert_eq(_main.get_board().pieces_root.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(_main.get_board().get_pieces().size(), 0, "las dos Piedras se eliminan")


func test_restart_after_game_over_resets_everything() -> void:
	_spawn(1, Vector2(100.0, 500.0))
	_spawn(3, Vector2(300.0, 500.0))
	_main.get_state().add_score(5)
	_main.get_state().set_game_over()
	_main.get_ui().restart_requested.emit()
	var state: GameState = _main.get_state()
	assert_eq(_main.get_board().get_pieces().size(), 0)
	assert_eq(state.get_score(), 0)
	assert_eq(state.get_status(), GameState.Status.PLAYING)
	assert_eq(_main.get_merge_system().get_pending_count(), 0)
	assert_eq(_main.get_board().pieces_root.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_not_null(state.get_current_piece())
	assert_not_null(state.get_next_piece())


func test_restart_with_pending_merge_leaves_no_ghost_pieces() -> void:
	var a: Piece = _spawn(1, Vector2(100.0, 500.0))
	var b: Piece = _spawn(1, Vector2(116.0, 500.0))
	_main.get_merge_system().handle_contact(a, b)
	assert_eq(_main.get_merge_system().get_pending_count(), 1)
	_main.get_state().set_game_over()
	_main.get_ui().restart_requested.emit()
	assert_eq(_main.get_merge_system().get_pending_count(), 0)
	await wait_physics_frames(10)
	assert_eq(_main.get_board().get_pieces().size(), 0, "ninguna pieza fantasma")


func test_controller_restart_is_ignored_while_playing() -> void:
	_spawn(1, Vector2(100.0, 500.0))
	_main.get_state().add_score(5)
	_main.get_drop_controller().restart_requested.emit()
	assert_eq(_main.get_board().get_pieces().size(), 1)
	assert_eq(_main.get_state().get_score(), 5)
	assert_true(_main.get_state().is_playing())


func test_debug_strategy_request_restarts_the_game() -> void:
	_spawn(3, Vector2(300.0, 500.0))
	_main.get_state().add_score(7)
	_main.get_debug_controller().strategy_requested.emit(1)
	var state: GameState = _main.get_state()
	assert_eq(state.get_status(), GameState.Status.PLAYING)
	assert_eq(state.get_score(), 0)
	assert_eq(_main.get_board().get_pieces().size(), 0)


func test_debug_high_piece_replaces_current_with_one_below_max() -> void:
	var catalog: PieceCatalog = _config.piece_catalog
	_main.get_debug_controller().high_piece_requested.emit()
	assert_same(_main.get_state().get_current_piece(),
			catalog.get_by_level(catalog.get_max_level() - 1))


func test_finished_game_with_points_emits_new_record_and_shows_the_label() -> void:
	_main.get_state().add_score(12)
	_main.get_state().set_game_over()
	var label: Label = _main.get_ui().get_node("Root/GameOverView/VBox/NewRecord") as Label
	assert_true(label.visible, "¡Nuevo récord!")
	assert_eq((_main.get_ui().get_node("Root/LeftPanel/BestValue") as Label).text, "Récord: 12")


func test_finished_game_without_points_is_not_a_record() -> void:
	_main.get_state().set_game_over()
	var label: Label = _main.get_ui().get_node("Root/GameOverView/VBox/NewRecord") as Label
	assert_false(label.visible)


func test_title_waits_in_ready_and_the_starting_click_does_not_drop() -> void:
	var titled: Main = _make_titled_main()
	var state: GameState = titled.get_state()
	assert_eq(state.get_status(), GameState.Status.READY)
	assert_eq(titled.get_board().get_pieces().size(), 0)
	assert_true(titled.get_ui().get_node("Root/TitleView").visible, "se ve la vista de título")
	titled.get_drop_controller().drop_requested.emit()
	assert_eq(state.get_status(), GameState.Status.PLAYING)
	assert_eq(titled.get_board().get_pieces().size(), 0, "el clic que empieza no suelta")
	assert_false(titled.get_ui().get_node("Root/TitleView").visible)
	titled.get_drop_controller().drop_requested.emit()
	assert_eq(titled.get_board().get_pieces().size(), 1, "el siguiente clic sí suelta")


func test_title_button_starts_the_game() -> void:
	var titled: Main = _make_titled_main()
	titled.get_ui().start_requested.emit()
	assert_true(titled.get_state().is_playing())
	assert_eq(titled.get_board().get_pieces().size(), 0)


func test_pause_request_pauses_and_resumes_the_tree() -> void:
	_main.get_drop_controller().pause_requested.emit()
	assert_true(get_tree().paused)
	assert_true(_main.get_ui().get_node("Root/PauseView").visible)
	_main.get_drop_controller().pause_requested.emit()
	assert_false(get_tree().paused)
	assert_false(_main.get_ui().get_node("Root/PauseView").visible)


func test_drop_request_while_paused_creates_no_piece() -> void:
	_main.get_drop_controller().pause_requested.emit()
	_main.get_drop_controller().drop_requested.emit()
	assert_eq(_main.get_board().get_pieces().size(), 0)
	_main.get_drop_controller().pause_requested.emit()
	_main.get_drop_controller().drop_requested.emit()
	assert_eq(_main.get_board().get_pieces().size(), 1, "al reanudar, suelta")


func test_pause_request_outside_playing_does_nothing() -> void:
	_main.get_state().set_game_over()
	_main.get_drop_controller().pause_requested.emit()
	assert_false(get_tree().paused)
	var titled: Main = _make_titled_main()
	titled.get_drop_controller().pause_requested.emit()
	assert_false(get_tree().paused, "tampoco en el título")


func test_resume_button_unpauses() -> void:
	_main.get_drop_controller().pause_requested.emit()
	_main.get_ui().resume_requested.emit()
	assert_false(get_tree().paused)


func test_restart_while_paused_restarts_and_unpauses() -> void:
	_spawn(3, Vector2(300.0, 500.0))
	_main.get_state().add_score(9)
	_main.get_drop_controller().pause_requested.emit()
	_main.get_ui().restart_requested.emit()
	assert_false(get_tree().paused)
	assert_false(_main.get_ui().get_node("Root/PauseView").visible)
	assert_eq(_main.get_board().get_pieces().size(), 0)
	assert_eq(_main.get_state().get_score(), 0)
	assert_true(_main.get_state().is_playing())


func test_losing_window_focus_pauses_a_running_game() -> void:
	_main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(get_tree().paused)


func test_losing_window_focus_in_the_title_does_not_pause() -> void:
	var titled: Main = _make_titled_main()
	titled.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(get_tree().paused)
