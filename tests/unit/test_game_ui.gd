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


func _make_ui_with_scores(scores: ScoreStore) -> GameUI:
	var ui := (load("res://ui/game_ui.tscn") as PackedScene).instantiate() as GameUI
	add_child_autofree(ui)
	ui.setup(_state, _catalog, scores)
	return ui


func test_best_label_follows_the_store() -> void:
	var scores := ScoreStore.new("")
	scores.submit(25)
	var ui: GameUI = _make_ui_with_scores(scores)
	var label: Label = ui.get_node("Root/LeftPanel/BestValue") as Label
	assert_true(label.visible)
	assert_eq(label.text, "Récord: 25")
	scores.submit(60)
	assert_eq(label.text, "Récord: 60")


func test_best_label_is_hidden_without_a_store() -> void:
	assert_false((_node("Root/LeftPanel/BestValue") as Label).visible)


func test_new_record_label_shows_in_game_over_and_hides_on_restart() -> void:
	var scores := ScoreStore.new("")
	var ui: GameUI = _make_ui_with_scores(scores)
	var label: Label = ui.get_node("Root/GameOverView/VBox/NewRecord") as Label
	_state.add_score(5)
	_state.set_game_over()
	assert_false(label.visible, "sin récord, oculta")
	scores.submit(5)
	assert_true(label.visible, "con récord, visible")
	_state.reset()
	assert_false(label.visible, "se oculta al reiniciar")


func test_new_record_label_survives_the_victory_delay() -> void:
	var scores := ScoreStore.new("")
	var ui: GameUI = _make_ui_with_scores(scores)
	ui.victory_view_delay = 0.05
	_state.add_score(5)
	_state.set_victory()
	scores.submit(5)
	var view: Control = ui.get_node("Root/VictoryView") as Control
	assert_true(await wait_until(func() -> bool: return view.visible, 2.0))
	assert_true((ui.get_node("Root/VictoryView/VBox/NewRecord") as Label).visible)


func test_title_view_shows_only_while_ready() -> void:
	var title: Control = _node("Root/TitleView") as Control
	assert_false(title.visible, "en PLAYING no se ve")
	_state.reset()
	assert_true(title.visible, "en READY se ve")
	_state.start()
	assert_false(title.visible)


func test_pause_view_follows_set_paused() -> void:
	var pause: Control = _node("Root/PauseView") as Control
	assert_false(pause.visible)
	_ui.set_paused(true)
	assert_true(pause.visible)
	_ui.set_paused(false)
	assert_false(pause.visible)


func test_start_resume_and_pause_restart_buttons_emit_their_signals() -> void:
	watch_signals(_ui)
	(_node("Root/TitleView/VBox/StartButton") as Button).pressed.emit()
	(_node("Root/PauseView/VBox/ResumeButton") as Button).pressed.emit()
	(_node("Root/PauseView/VBox/RestartButton") as Button).pressed.emit()
	assert_signal_emit_count(_ui, "start_requested", 1)
	assert_signal_emit_count(_ui, "resume_requested", 1)
	assert_signal_emit_count(_ui, "restart_requested", 1)
	assert_signal_emit_count(_ui, "button_pressed", 3)


func test_ui_keeps_processing_while_paused() -> void:
	assert_eq(_ui.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_legend_rows_have_a_colored_rarity_chip() -> void:
	var legend: VBoxContainer = _node("Root/RightPanel/Legend") as VBoxContainer
	for i: int in _catalog.size():
		var data: PieceData = _catalog.get_by_level(i + 1)
		var chip: PanelContainer = legend.get_child(i).get_child(2) as PanelContainer
		var style: StyleBoxFlat = chip.get_theme_stylebox("panel") as StyleBoxFlat
		assert_eq(style.bg_color, data.rarity_color, "color de la etiqueta de %s" % data.id)
		assert_eq((chip.get_child(0) as Label).text, data.rarity_label)


func test_legend_chip_text_contrasts_with_its_background() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.get_by_level(1).rarity_color = Color(1.0, 0.9, 0.4)
	catalog.get_by_level(2).rarity_color = Color(0.1, 0.1, 0.4)
	var ui := (load("res://ui/game_ui.tscn") as PackedScene).instantiate() as GameUI
	add_child_autofree(ui)
	ui.setup(GameState.new(), catalog)
	var legend: VBoxContainer = ui.get_node("Root/RightPanel/Legend") as VBoxContainer
	var on_light: Label = legend.get_child(0).get_child(2).get_child(0) as Label
	var on_dark: Label = legend.get_child(1).get_child(2).get_child(0) as Label
	assert_lt(on_light.get_theme_color("font_color").get_luminance(),
			on_dark.get_theme_color("font_color").get_luminance(), "texto oscuro sobre fondo claro")


func test_root_uses_the_ui_theme_and_views_have_no_local_panel_override() -> void:
	assert_eq((_node("Root") as Control).theme.resource_path, "res://ui/theme.tres")
	for view: String in ["GameOverView", "VictoryView", "TitleView", "PauseView"]:
		assert_false((_node("Root/%s" % view) as Control).has_theme_stylebox_override("panel"),
				"%s no debe anular el panel del tema" % view)


func test_panel_fallback_replaces_a_textureless_parchment() -> void:
	var theme := Theme.new()
	theme.set_stylebox(&"panel", &"PanelContainer", StyleBoxTexture.new())
	var flat := StyleBoxFlat.new()
	theme.set_stylebox(&"panel_fallback", &"PanelContainer", flat)
	GameUI.apply_panel_fallback(theme)
	assert_same(theme.get_stylebox(&"panel", &"PanelContainer"), flat)


func test_panel_fallback_keeps_a_textured_parchment() -> void:
	var theme := Theme.new()
	var parchment := StyleBoxTexture.new()
	parchment.texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	theme.set_stylebox(&"panel", &"PanelContainer", parchment)
	theme.set_stylebox(&"panel_fallback", &"PanelContainer", StyleBoxFlat.new())
	GameUI.apply_panel_fallback(theme)
	assert_same(theme.get_stylebox(&"panel", &"PanelContainer"), parchment)
	GameUI.apply_panel_fallback(null)
	assert_true(true, "un tema nulo no falla")
