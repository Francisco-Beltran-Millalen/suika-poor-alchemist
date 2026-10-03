class_name PieceSpawner
extends Node
## Único lugar que instancia `piece.tscn`.

signal piece_spawned(piece: Piece)

const PIECE_SCENE: PackedScene = preload("res://piece/piece.tscn")

var _pieces_root: Node2D


func setup(pieces_root: Node2D) -> void:
	_pieces_root = pieces_root


## Crea la pieza (`setup` → `add_child` → señal). `position` en coordenadas de tablero.
func spawn(data: PieceData, position: Vector2, initial_state: Piece.State) -> Piece:
	var piece := PIECE_SCENE.instantiate() as Piece
	piece.setup(data, initial_state)
	piece.position = position
	_pieces_root.add_child(piece)
	piece_spawned.emit(piece)
	return piece


## Quita la pieza de inmediato (`remove_child` + `queue_free`).
func despawn(piece: Piece) -> void:
	if piece.get_parent() == _pieces_root:
		_pieces_root.remove_child(piece)
	piece.queue_free()
