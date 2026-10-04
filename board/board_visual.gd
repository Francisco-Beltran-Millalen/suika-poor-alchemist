class_name BoardVisual
extends Node2D
## Dibuja una capa del recipiente: el interior (detrás de las piezas) o las
## paredes y reflejos (delante). Sin textura, dibuja el placeholder procedural.

enum Layer { BACK, FRONT }

const _BACKGROUND_COLOR := Color(0.13, 0.095, 0.07)
const _WALL_COLOR := Color(0.36, 0.24, 0.14)
const _WALL_EDGE_COLOR := Color(0.55, 0.38, 0.22)
const _WALL_GRAIN_COLOR := Color(0.27, 0.17, 0.1)
const _PLANK_SPACING: float = 48.0

@export var layer: Layer = Layer.BACK
@export var skin: BoardSkin

var _config: GameConfig


func _draw() -> void:
	if _config == null:
		return
	if layer == Layer.BACK:
		_draw_back()
	else:
		_draw_front()


func setup(config: GameConfig) -> void:
	_config = config
	queue_redraw()


func _draw_back() -> void:
	var interior := Rect2(0.0, 0.0, _config.container_width, _config.container_height)
	if skin != null and skin.back_texture != null:
		draw_texture_rect(skin.back_texture, interior, false)
	else:
		draw_rect(interior, _BACKGROUND_COLOR)
	var danger_color: Color = skin.danger_color if skin != null else BoardSkin.new().danger_color
	draw_dashed_line(Vector2(0.0, _config.danger_line_y),
			Vector2(_config.container_width, _config.danger_line_y), danger_color, 2.0, 10.0)


# Con textura, el exterior empieza en `y = 0`: la parte de las paredes de
# colisión que sube por encima de la boca queda invisible a propósito.
func _draw_front() -> void:
	if skin != null and skin.front_texture != null:
		var t: float = _config.wall_thickness
		draw_texture_rect(skin.front_texture, Rect2(-t, 0.0, _config.container_width + 2.0 * t,
				_config.container_height + t), false)
		return
	for rect: Rect2 in _wall_rects():
		_draw_wall(rect)


# Pared de madera: relleno, tablones (juntas) y filo claro hacia el interior.
func _draw_wall(rect: Rect2) -> void:
	draw_rect(rect, _WALL_COLOR)
	var is_floor: bool = rect.size.x > rect.size.y
	if is_floor:
		var x: float = rect.position.x + _PLANK_SPACING
		while x < rect.end.x:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), _WALL_GRAIN_COLOR, 2.0)
			x += _PLANK_SPACING
		draw_line(rect.position, Vector2(rect.end.x, rect.position.y), _WALL_EDGE_COLOR, 3.0)
	else:
		var y: float = rect.position.y + _PLANK_SPACING
		while y < rect.end.y:
			draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), _WALL_GRAIN_COLOR, 2.0)
			y += _PLANK_SPACING
		var inner_x: float = rect.end.x if rect.position.x < 0.0 else rect.position.x
		draw_line(Vector2(inner_x, rect.position.y), Vector2(inner_x, rect.end.y), _WALL_EDGE_COLOR, 3.0)


# Mismos rectángulos que las paredes de colisión de `Board`. No se llama a
# `Board` para evitar una referencia circular entre ambas clases.
func _wall_rects() -> Array[Rect2]:
	var width: float = _config.container_width
	var height: float = _config.container_height
	var t: float = _config.wall_thickness
	var e: float = DangerZone.EXTENSION_ABOVE
	var rects: Array[Rect2] = []
	rects.append(Rect2(-t, -e, t, height + e))
	rects.append(Rect2(width, -e, t, height + e))
	rects.append(Rect2(-t, height, width + 2.0 * t, t))
	return rects
