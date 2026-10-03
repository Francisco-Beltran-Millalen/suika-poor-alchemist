class_name PieceCatalog
extends Resource
## Conjunto ordenado de materiales (por `level`, empezando en 1).

@export var pieces: Array[PieceData] = []


## Devuelve el material del nivel dado, o `null` si está fuera de rango.
func get_by_level(level: int) -> PieceData:
	if level < 1 or level > pieces.size():
		return null
	return pieces[level - 1]


## Nivel más alto del catálogo.
func get_max_level() -> int:
	return pieces.size()


## Número de materiales.
func size() -> int:
	return pieces.size()
