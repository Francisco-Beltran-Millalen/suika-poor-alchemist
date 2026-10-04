class_name DropPreview
extends Node2D
## Dibuja el ACTUAL en la posición de apuntado, con una línea guía hasta el fondo.

const _GUIDE_COLOR := Color(1.0, 1.0, 1.0, 0.25)
const _COOLDOWN_ALPHA: float = 0.4

## Sprite opcional del artefacto del alquimista, sobre la pieza ACTUAL.
@export var dropper_texture: Texture2D
## Lado en px de juego con el que se dibuja (el PNG es de 256: 4× de resolución).
@export var dropper_size: float = 64.0

var _state: GameState
var _config: GameConfig
var _aim_x: float = 0.0
var _is_ready: bool = true


func _draw() -> void:
	if _state == null or not _state.is_playing():
		return
	var data: PieceData = _state.get_current_piece()
	if data == null:
		return
	var origin := Vector2(_aim_x, _config.spawn_y)
	var alpha: float = 1.0 if _is_ready else _COOLDOWN_ALPHA
	draw_dashed_line(origin + Vector2(0.0, data.radius), Vector2(_aim_x, _config.container_height),
			_GUIDE_COLOR, 2.0, 8.0)
	PieceVisual.draw_piece(self, data, origin, data.radius, alpha)
	if dropper_texture != null:
		# Su borde inferior queda justo encima de la pieza, también en el cooldown.
		var top_left := Vector2(_aim_x - dropper_size / 2.0, _config.spawn_y - data.radius - dropper_size)
		draw_texture_rect(dropper_texture, Rect2(top_left, Vector2(dropper_size, dropper_size)), false)


func setup(state: GameState, drop_system: DropSystem, config: GameConfig) -> void:
	_state = state
	_config = config
	_aim_x = drop_system.get_aim_x()
	state.current_piece_changed.connect(_on_state_current_piece_changed)
	state.status_changed.connect(_on_state_status_changed)
	drop_system.aim_changed.connect(_on_drop_system_aim_changed)
	drop_system.drop_ready_changed.connect(_on_drop_system_drop_ready_changed)
	queue_redraw()


func _on_state_current_piece_changed(_data: PieceData) -> void:
	queue_redraw()


func _on_state_status_changed(_status: GameState.Status) -> void:
	queue_redraw()


func _on_drop_system_aim_changed(x: float) -> void:
	_aim_x = x
	queue_redraw()


func _on_drop_system_drop_ready_changed(is_ready: bool) -> void:
	_is_ready = is_ready
	queue_redraw()
