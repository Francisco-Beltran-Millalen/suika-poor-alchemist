extends DangerZone
## Zona de peligro de test: devuelve las piezas que se le asignan. Sin `class_name`.

var pieces: Array[Piece] = []


func get_pieces_inside() -> Array[Piece]:
	return pieces
