class_name Board
extends Node2D
## Recipiente físico: paredes, zona de peligro y contenedor de piezas.
##
## Coordenadas de tablero: origen en la esquina superior izquierda del interior.

const WALL_EXTENSION_ABOVE: float = DangerZone.EXTENSION_ABOVE

const _BACKGROUND_COLOR := Color(0.13, 0.095, 0.07)
const _WALL_COLOR := Color(0.36, 0.24, 0.14)
const _WALL_EDGE_COLOR := Color(0.55, 0.38, 0.22)
const _WALL_GRAIN_COLOR := Color(0.27, 0.17, 0.1)
const _PLANK_SPACING: float = 48.0
const _DANGER_COLOR := Color(0.91, 0.2, 0.24, 0.8)

var _config: GameConfig

@onready var danger_zone: DangerZone = $DangerZone
@onready var pieces_root: Node2D = $Pieces
@onready var _walls: StaticBody2D = $Walls


func _draw() -> void:
	if _config == null:
		return
	var width: float = _config.container_width
	var height: float = _config.container_height
	draw_rect(Rect2(0.0, 0.0, width, height), _BACKGROUND_COLOR)
	for rect: Rect2 in _wall_rects():
		_draw_wall(rect)
	draw_dashed_line(Vector2(0.0, _config.danger_line_y), Vector2(width, _config.danger_line_y),
			_DANGER_COLOR, 2.0, 10.0)


## Construye las tres paredes y la zona de peligro a partir de la configuración.
func setup(config: GameConfig) -> void:
	_config = config
	for child: Node in _walls.get_children():
		_walls.remove_child(child)
		child.queue_free()
	var names: Array[String] = ["LeftWall", "RightWall", "Floor"]
	var rects: Array[Rect2] = _wall_rects()
	for i: int in names.size():
		var shape := RectangleShape2D.new()
		shape.size = rects[i].size
		var node := CollisionShape2D.new()
		node.name = names[i]
		node.shape = shape
		node.position = rects[i].get_center()
		_walls.add_child(node)
	danger_zone.setup(config)
	queue_redraw()


## Limita la X de soltado a `[radius, W − radius]`.
func clamp_drop_x(x: float, radius: float) -> float:
	return clampf(x, radius, _config.container_width - radius)


## Como `clamp_drop_x`, y además `y ≤ H − radius`.
func clamp_piece_position(pos: Vector2, radius: float) -> Vector2:
	return Vector2(clamp_drop_x(pos.x, radius),
			minf(pos.y, _config.container_height - radius))


## Congela (o descongela) todas las piezas; quedan quietas y visibles.
func set_frozen(frozen: bool) -> void:
	pieces_root.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_INHERIT


## Elimina todas las piezas de inmediato (el recuento es correcto en el mismo frame).
func clear_pieces() -> void:
	for child: Node in pieces_root.get_children():
		pieces_root.remove_child(child)
		child.queue_free()


func get_pieces() -> Array[Piece]:
	var result: Array[Piece] = []
	for child: Node in pieces_root.get_children():
		if child is Piece:
			result.append(child as Piece)
	return result


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


## Rectángulos de las paredes (izquierda, derecha, suelo) en coordenadas de tablero.
func _wall_rects() -> Array[Rect2]:
	var width: float = _config.container_width
	var height: float = _config.container_height
	var t: float = _config.wall_thickness
	var e: float = WALL_EXTENSION_ABOVE
	var rects: Array[Rect2] = []
	rects.append(Rect2(-t, -e, t, height + e))
	rects.append(Rect2(width, -e, t, height + e))
	rects.append(Rect2(-t, height, width + 2.0 * t, t))
	return rects
