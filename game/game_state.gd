class_name GameState
extends RefCounted
## Estado lógico de una partida: puntuación, cola de piezas y estado.
##
## `score_changed` y `status_changed` solo se emiten si el valor cambia (salvo en
## `reset()`). Las señales de la cola se emiten siempre, aunque el recurso sea el
## mismo, para que los observadores se enteren de cada avance.

signal score_changed(score: int)
signal current_piece_changed(data: PieceData)
signal next_piece_changed(data: PieceData)
signal status_changed(status: Status)

enum Status { READY, PLAYING, GAME_OVER, VICTORY }

var _score: int = 0
var _status: Status = Status.READY
var _current_piece: PieceData
var _next_piece: PieceData


func get_score() -> int:
	return _score


func get_status() -> Status:
	return _status


func get_current_piece() -> PieceData:
	return _current_piece


func get_next_piece() -> PieceData:
	return _next_piece


func is_playing() -> bool:
	return _status == Status.PLAYING


## `GAME_OVER` o `VICTORY`. `Main` lo usa para congelar y reiniciar.
func is_finished() -> bool:
	return _status == Status.GAME_OVER or _status == Status.VICTORY


## `READY` → `PLAYING`. Devuelve `false` si no estaba en `READY`.
func start() -> bool:
	return _transition(Status.READY, Status.PLAYING)


## Suma puntos. Se ignora fuera de `PLAYING`.
func add_score(amount: int) -> void:
	assert(amount >= 0, "add_score: amount no puede ser negativo")
	if _status != Status.PLAYING or amount == 0:
		return
	_score += amount
	score_changed.emit(_score)


func set_queue(current: PieceData, next: PieceData) -> void:
	_current_piece = current
	_next_piece = next
	current_piece_changed.emit(_current_piece)
	next_piece_changed.emit(_next_piece)


## Desplaza la cola (ACTUAL ← PRÓXIMO, PRÓXIMO ← `new_next`) y devuelve el ACTUAL saliente.
func advance_queue(new_next: PieceData) -> PieceData:
	var outgoing: PieceData = _current_piece
	_current_piece = _next_piece
	_next_piece = new_next
	current_piece_changed.emit(_current_piece)
	next_piece_changed.emit(_next_piece)
	return outgoing


## `PLAYING` → `GAME_OVER`.
func set_game_over() -> bool:
	return _transition(Status.PLAYING, Status.GAME_OVER)


## `PLAYING` → `VICTORY`.
func set_victory() -> bool:
	return _transition(Status.PLAYING, Status.VICTORY)


## Puntuación 0, cola nula y `READY`. Emite las cuatro señales siempre.
func reset() -> void:
	_score = 0
	_status = Status.READY
	_current_piece = null
	_next_piece = null
	score_changed.emit(_score)
	current_piece_changed.emit(null)
	next_piece_changed.emit(null)
	status_changed.emit(_status)


func _transition(from: Status, to: Status) -> bool:
	if _status != from:
		return false
	_status = to
	status_changed.emit(_status)
	return true
