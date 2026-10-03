class_name MergeSystem
extends Node
## Valida contactos, marca piezas consumidas y resuelve fusiones.
##
## No puntúa ni decide el fin de la partida: solo emite señales.

signal pieces_merged(source: PieceData, result: PieceData, position: Vector2)
signal max_level_merged(source: PieceData, position: Vector2)

var _state: GameState
var _spawner: PieceSpawner
var _board: Board
# Pares aceptados pendientes de resolver, en orden de aceptación (índices paralelos).
var _pending_a: Array[Piece] = []
var _pending_b: Array[Piece] = []


func _physics_process(_delta: float) -> void:
	tick()


func setup(state: GameState, spawner: PieceSpawner, board: Board) -> void:
	_state = state
	_spawner = spawner
	_board = board


## Se suscribe a los contactos de una pieza (lo llama `Main` vía `piece_spawned`).
func register_piece(piece: Piece) -> void:
	piece.contact_detected.connect(handle_contact)


## Acepta o ignora un contacto. Ocurre durante el flush de física: no se crean
## ni eliminan cuerpos aquí, solo se marca y se encola.
func handle_contact(a: Piece, b: Piece) -> void:
	if not _state.is_playing() or a == b or a.data != b.data:
		return
	if a.is_consumed() or b.is_consumed():
		return
	a.consume()
	b.consume()
	_pending_a.append(a)
	_pending_b.append(b)


## Resuelve las fusiones pendientes (una vez por paso de física).
func tick() -> void:
	if _pending_a.is_empty():
		return
	# Copias locales: las señales emitidas aquí pueden reiniciar el sistema.
	var pairs_a: Array[Piece] = _pending_a.duplicate()
	var pairs_b: Array[Piece] = _pending_b.duplicate()
	reset()
	for i: int in pairs_a.size():
		if not _state.is_playing():
			return
		_resolve(pairs_a[i], pairs_b[i])


## Cancela las fusiones pendientes.
func reset() -> void:
	_pending_a.clear()
	_pending_b.clear()


func get_pending_count() -> int:
	return _pending_a.size()


func _resolve(a: Piece, b: Piece) -> void:
	var position: Vector2 = (a.position + b.position) / 2.0
	var source: PieceData = a.data
	# Primero se eliminan, para que la nueva pieza nunca se solape con ellas.
	_spawner.despawn(a)
	_spawner.despawn(b)
	if source.is_max_level():
		max_level_merged.emit(source, position)
		return
	var result: PieceData = source.next_piece
	var clamped: Vector2 = _board.clamp_piece_position(position, result.radius)
	_spawner.spawn(result, clamped, Piece.State.ACTIVE)
	pieces_merged.emit(source, result, clamped)
