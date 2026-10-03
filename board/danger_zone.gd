class_name DangerZone
extends Area2D
## Franja sobre la línea de peligro: detecta las piezas que la rebasan.

## Hasta dónde sube la zona sobre el borde superior (coincide con las paredes).
const EXTENSION_ABOVE: float = 400.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D


## Rectángulo de `y = −EXTENSION_ABOVE` a `y = danger_line_y`, de ancho `container_width`.
func setup(config: GameConfig) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(config.container_width, config.danger_line_y + EXTENSION_ABOVE)
	_collision_shape.shape = shape
	_collision_shape.position = Vector2(config.container_width / 2.0,
			(config.danger_line_y - EXTENSION_ABOVE) / 2.0)


## Piezas solapadas. Los solapes van un paso de física por detrás: una pieza
## quitada con `remove_child` sigue apareciendo en el mismo frame y una recién
## añadida tarda ~2 frames; de ahí los filtros.
func get_pieces_inside() -> Array[Piece]:
	var result: Array[Piece] = []
	for body: Node2D in get_overlapping_bodies():
		if body is Piece and is_instance_valid(body) and body.is_inside_tree():
			result.append(body as Piece)
	return result
