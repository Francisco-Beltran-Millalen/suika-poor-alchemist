class_name GameUI
extends CanvasLayer
## HUD: puntuación, récord, PRÓXIMO, leyenda de rareza y las pantallas de
## título, pausa y fin de partida. Procesa también en pausa.
##
## Observa el estado; nunca lo modifica. El reinicio sale como intención.

signal restart_requested
## Se emite al pulsar cualquier botón (para el sonido de clic).
signal button_pressed
signal resume_requested
## Botón de la vista de título.
signal start_requested

const _CHIP_FONT_SIZE: int = 12
const _CHIP_CORNER_RADIUS: int = 4
const _CHIP_DARK_TEXT := Color(0.15, 0.1, 0.05)
const _CHIP_LIGHT_TEXT := Color.WHITE
## Por encima de esta luminancia, el texto de la etiqueta de rareza es oscuro.
const _CHIP_LIGHT_BACKGROUND: float = 0.55

## Segundos hasta mostrar la pantalla de victoria (deja ver la animación).
@export var victory_view_delay: float = 1.5

var _state: GameState
# El récord llega con `new_record` justo después de `status_changed`, y la
# vista de victoria se muestra con retraso: se recuerda hasta el próximo reinicio.
var _is_new_record: bool = false

@onready var _score_value: Label = $Root/LeftPanel/ScoreValue
@onready var _next_piece: PieceIcon = $Root/RightPanel/NextPiece
@onready var _legend: VBoxContainer = $Root/RightPanel/Legend
@onready var _game_over_view: PanelContainer = $Root/GameOverView
@onready var _game_over_score: Label = $Root/GameOverView/VBox/FinalScore
@onready var _victory_view: PanelContainer = $Root/VictoryView
@onready var _victory_score: Label = $Root/VictoryView/VBox/FinalScore
@onready var _victory_timer: Timer = $VictoryTimer
@onready var _debug_label: Label = $Root/DebugLabel
@onready var _title_view: PanelContainer = $Root/TitleView
@onready var _pause_view: PanelContainer = $Root/PauseView
@onready var _best_value: Label = $Root/LeftPanel/BestValue
@onready var _game_over_record: Label = $Root/GameOverView/VBox/NewRecord
@onready var _victory_record: Label = $Root/VictoryView/VBox/NewRecord


func _ready() -> void:
	apply_panel_fallback(($Root as Control).theme)
	($Root/GameOverView/VBox/RestartButton as Button).pressed.connect(_on_restart_button_pressed)
	($Root/VictoryView/VBox/RestartButton as Button).pressed.connect(_on_restart_button_pressed)
	($Root/TitleView/VBox/StartButton as Button).pressed.connect(_on_start_button_pressed)
	($Root/PauseView/VBox/ResumeButton as Button).pressed.connect(_on_resume_button_pressed)
	($Root/PauseView/VBox/RestartButton as Button).pressed.connect(_on_restart_button_pressed)
	_victory_timer.timeout.connect(_on_victory_timer_timeout)


## `scores` es opcional: con `null` no se muestra el récord.
func setup(state: GameState, catalog: PieceCatalog, scores: ScoreStore = null) -> void:
	_state = state
	_build_legend(catalog)
	_best_value.visible = scores != null
	if scores != null:
		scores.best_changed.connect(_on_scores_best_changed)
		scores.new_record.connect(_on_scores_new_record)
		_on_scores_best_changed(scores.get_best())
	state.score_changed.connect(_on_state_score_changed)
	state.next_piece_changed.connect(_on_state_next_piece_changed)
	state.status_changed.connect(_on_state_status_changed)
	_on_state_score_changed(state.get_score())
	_on_state_next_piece_changed(state.get_next_piece())
	_on_state_status_changed(state.get_status())


## Si el pergamino del tema no tiene textura, usa el panel plano de respaldo
## (`panel_fallback`, del mismo tema). Así quitar el PNG nunca rompe la interfaz.
static func apply_panel_fallback(theme: Theme) -> void:
	if theme == null or not theme.has_stylebox(&"panel", &"PanelContainer") \
			or not theme.has_stylebox(&"panel_fallback", &"PanelContainer"):
		return
	var panel := theme.get_stylebox(&"panel", &"PanelContainer") as StyleBoxTexture
	if panel != null and panel.texture == null:
		theme.set_stylebox(&"panel", &"PanelContainer",
				theme.get_stylebox(&"panel_fallback", &"PanelContainer"))


## Muestra u oculta la vista de pausa.
func set_paused(paused: bool) -> void:
	_pause_view.visible = paused


## Texto de depuración en una esquina; cadena vacía lo oculta.
func set_debug_text(text: String) -> void:
	_debug_label.text = text
	_debug_label.visible = not text.is_empty()


func _build_legend(catalog: PieceCatalog) -> void:
	for child: Node in _legend.get_children():
		_legend.remove_child(child)
		child.queue_free()
	for data: PieceData in catalog.pieces:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		var icon := PieceIcon.new()
		icon.custom_minimum_size = Vector2(24.0, 24.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_piece(data)
		var label := Label.new()
		label.text = data.display_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.add_child(label)
		row.add_child(_make_rarity_chip(data))
		_legend.add_child(row)


# Etiqueta de rareza como en la referencia: píldora del color de `rarity_color`.
func _make_rarity_chip(data: PieceData) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = data.rarity_color
	style.set_corner_radius_all(_CHIP_CORNER_RADIUS)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	chip.add_theme_stylebox_override("panel", style)
	var text := Label.new()
	text.text = data.rarity_label
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("font_size", _CHIP_FONT_SIZE)
	var dark: bool = data.rarity_color.get_luminance() > _CHIP_LIGHT_BACKGROUND
	text.add_theme_color_override("font_color", _CHIP_DARK_TEXT if dark else _CHIP_LIGHT_TEXT)
	chip.add_child(text)
	return chip


func _show_end_view(view: Control) -> void:
	var text: String = "Puntuación final: %d" % _state.get_score()
	_game_over_score.text = text
	_victory_score.text = text
	_game_over_record.visible = _is_new_record
	_victory_record.visible = _is_new_record
	view.show()


func _on_state_score_changed(score: int) -> void:
	_score_value.text = str(score)


func _on_state_next_piece_changed(data: PieceData) -> void:
	_next_piece.set_piece(data)


func _on_state_status_changed(status: GameState.Status) -> void:
	# Cualquier cambio distinto de GAME_OVER/VICTORY oculta ambas vistas y cancela
	# el retardo: una victoria reiniciada a tiempo no debe mostrarse sobre la nueva partida.
	_victory_timer.stop()
	_game_over_view.hide()
	_victory_view.hide()
	_title_view.visible = status == GameState.Status.READY
	if not _state.is_finished():
		_is_new_record = false
		_game_over_record.hide()
		_victory_record.hide()
	match status:
		GameState.Status.GAME_OVER:
			_show_end_view(_game_over_view)
		GameState.Status.VICTORY:
			if victory_view_delay > 0.0:
				_victory_timer.start(victory_view_delay)
			else:
				_show_end_view(_victory_view)


func _on_scores_best_changed(best: int) -> void:
	_best_value.text = "Récord: %d" % best


func _on_scores_new_record(_score: int) -> void:
	_is_new_record = true
	_game_over_record.visible = _game_over_view.visible
	_victory_record.visible = _victory_view.visible


func _on_victory_timer_timeout() -> void:
	_show_end_view(_victory_view)


func _on_start_button_pressed() -> void:
	button_pressed.emit()
	start_requested.emit()


func _on_resume_button_pressed() -> void:
	button_pressed.emit()
	resume_requested.emit()


func _on_restart_button_pressed() -> void:
	button_pressed.emit()
	restart_requested.emit()
