extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")

var _catalog: PieceCatalog
var _state: GameState
var _ui: GameUI


func before_each() -> void:
	_catalog = DataFactory.make_catalog()
	_state = GameState.new()
	_ui = (load("res://ui/game_ui.tscn") as PackedScene).instantiate() as GameUI
	add_child_autofree(_ui)
	_ui.setup(_state, _catalog)
	_state.reset()
	_state.start()


func _node(path: String) -> Node:
	return _ui.get_node(path)


func test_score_label_follows_state() -> void:
	_state.add_score(12)
	assert_eq((_node("Root/LeftPanel/ScoreValue") as Label).text, "12")


func test_next_piece_icon_follows_state() -> void:
	_state.set_queue(_catalog.get_by_level(1), _catalog.get_by_level(4))
	var icon: PieceIcon = _node("Root/RightPanel/NextPiece") as PieceIcon
	assert_same(icon.get("_data"), _catalog.get_by_level(4))


func test_legend_has_all_entries_in_order() -> void:
	var legend: VBoxContainer = _node("Root/RightPanel/Legend") as VBoxContainer
	assert_eq(legend.get_child_count(), _catalog.size())
	for i: int in _catalog.size():
		var label: Label = legend.get_child(i).get_child(1) as Label
		assert_true(label.text.begins_with(_catalog.get_by_level(i + 1).display_name))
		assert_eq((legend.get_child(i).get_child(0) as Control).custom_minimum_size, Vector2(24, 24))


func test_game_over_shows_view_with_final_score() -> void:
	_state.add_score(7)
	_state.set_game_over()
	var view: Control = _node("Root/GameOverView") as Control
	assert_true(view.visible)
	assert_false((_node("Root/VictoryView") as Control).visible)
	assert_eq((_node("Root/GameOverView/VBox/FinalScore") as Label).text, "Puntuación final: 7")


func test_restart_buttons_emit_restart_requested() -> void:
	watch_signals(_ui)
	(_node("Root/GameOverView/VBox/RestartButton") as Button).pressed.emit()
	(_node("Root/VictoryView/VBox/RestartButton") as Button).pressed.emit()
	assert_signal_emit_count(_ui, "restart_requested", 2)


func test_victory_view_appears_after_delay() -> void:
	_ui.victory_view_delay = 0.05
	_state.set_victory()
	var view: Control = _node("Root/VictoryView") as Control
	assert_false(view.visible, "todavía dentro del retardo")
	assert_true(await wait_until(func() -> bool: return view.visible, 2.0), "aparece tras el retardo")


func test_restart_before_victory_delay_never_shows_view() -> void:
	_ui.victory_view_delay = 0.1
	_state.set_victory()
	_state.reset()
	_state.start()
	await wait_seconds(0.3)
	assert_false((_node("Root/VictoryView") as Control).visible)
	assert_false((_node("Root/GameOverView") as Control).visible)


func test_reset_with_null_queue_does_not_error() -> void:
	_state.set_queue(_catalog.get_by_level(1), _catalog.get_by_level(2))
	_state.reset()
	assert_null((_node("Root/RightPanel/NextPiece") as PieceIcon).get("_data"))
	assert_eq((_node("Root/LeftPanel/ScoreValue") as Label).text, "0")


func test_non_interactive_containers_ignore_mouse() -> void:
	for path: String in ["Root", "Root/LeftPanel", "Root/RightPanel", "Root/RightPanel/Legend",
			"Root/RightPanel/NextPiece", "Root/GameOverView", "Root/VictoryView"]:
		assert_eq((_node(path) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, path)
