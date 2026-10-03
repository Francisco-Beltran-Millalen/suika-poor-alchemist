class_name Board
extends Node2D
## Recipiente físico: paredes, zona de peligro y contenedor de piezas.
##
## Coordenadas de tablero: origen en la esquina superior izquierda del interior.

const WALL_EXTENSION_ABOVE: float = DangerZone.EXTENSION_ABOVE

const _BACKGROUND_COLOR := Color(0.11, 0.09, 0.08)
const _WALL_COLOR := Color(0.36, 0.24, 0.14)
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
	var t: float = _config.wall_thickness
	draw_rect(Rect2(0.0, 0.0, width, height), _BACKGROUND_COLOR)
	for rect: Rect2 in _wall_rects():
		draw_rect(rect, _WALL_COLOR)
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
