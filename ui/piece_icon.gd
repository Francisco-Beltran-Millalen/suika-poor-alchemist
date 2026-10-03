class_name PieceIcon
extends Control
## Icono de un material, escalado al rectángulo del control.
##
## Dentro de un contenedor un `Control` sin tamaño mínimo mide 0×0: la escena
## que lo usa debe fijar `custom_minimum_size`.

const _FILL: float = 0.8

var _data: PieceData


func _draw() -> void:
	if _data == null:
		return
	var radius: float = minf(size.x, size.y) / 2.0 * _FILL
	PieceVisual.draw_piece(self, _data, size / 2.0, radius)


## `null` deja el icono vacío.
func set_piece(data: PieceData) -> void:
	_data = data
	queue_redraw()
