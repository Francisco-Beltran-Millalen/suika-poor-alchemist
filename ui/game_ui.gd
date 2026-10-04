class_name GameUI
extends CanvasLayer
## HUD: puntuación, PRÓXIMO, leyenda de rareza y pantallas de fin de partida.
##
## Observa el estado; nunca lo modifica. El reinicio sale como intención.

signal restart_requested
## Se emite al pulsar cualquier botón (para el sonido de clic).
signal button_pressed

## Segundos hasta mostrar la pantalla de victoria (deja ver la animación).
@export var victory_view_delay: float = 1.5

var _state: GameState

@onready var _score_value: Label = $Root/LeftPanel/ScoreValue
@onready var _next_piece: PieceIcon = $Root/RightPanel/NextPiece
@onready var _legend: VBoxContainer = $Root/RightPanel/Legend
@onready var _game_over_view: PanelContainer = $Root/GameOverView
@onready var _game_over_score: Label = $Root/GameOverView/VBox/FinalScore
@onready var _victory_view: PanelContainer = $Root/VictoryView
@onready var _victory_score: Label = $Root/VictoryView/VBox/FinalScore
@onready var _victory_timer: Timer = $VictoryTimer
@onready var _debug_label: Label = $Root/DebugLabel


func _ready() -> void:
	($Root/GameOverView/VBox/RestartButton as Button).pressed.connect(_on_restart_button_pressed)
	($Root/VictoryView/VBox/RestartButton as Button).pressed.connect(_on_restart_button_pressed)
	_victory_timer.timeout.connect(_on_victory_timer_timeout)


func setup(state: GameState, catalog: PieceCatalog) -> void:
	_state = state
	_build_legend(catalog)
	state.score_changed.connect(_on_state_score_changed)
	state.next_piece_changed.connect(_on_state_next_piece_changed)
	state.status_changed.connect(_on_state_status_changed)
	_on_state_score_changed(state.get_score())
	_on_state_next_piece_changed(state.get_next_piece())
	_on_state_status_changed(state.get_status())


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
		label.text = "%s · %s" % [data.display_name, data.rarity_label]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		row.add_child(label)
		_legend.add_child(row)


func _show_end_view(view: Control) -> void:
	var text: String = "Puntuación final: %d" % _state.get_score()
	_game_over_score.text = text
	_victory_score.text = text
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
	match status:
		GameState.Status.GAME_OVER:
			_show_end_view(_game_over_view)
		GameState.Status.VICTORY:
			if victory_view_delay > 0.0:
				_victory_timer.start(victory_view_delay)
			else:
				_show_end_view(_victory_view)


func _on_victory_timer_timeout() -> void:
	_show_end_view(_victory_view)


func _on_restart_button_pressed() -> void:
	button_pressed.emit()
	restart_requested.emit()
