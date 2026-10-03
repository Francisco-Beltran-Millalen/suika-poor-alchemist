class_name DropSystem
extends Node
## Convierte intenciones de apuntar y soltar en piezas: límite por radio,
## cooldown y avance de la cola.

signal aim_changed(x: float)
signal drop_ready_changed(is_ready: bool)
signal piece_dropped(piece: Piece)

var _state: GameState
var _generator: PieceGenerator
var _spawner: PieceSpawner
var _board: Board
var _config: GameConfig
# Intención del jugador, sin limitar por el radio: al pasar a una pieza más
# pequeña se recupera la posición original.
var _aim_x: float = 0.0
var _cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


func setup(state: GameState, generator: PieceGenerator, spawner: PieceSpawner,
		board: Board, config: GameConfig) -> void:
	_state = state
	_generator = generator
	_spawner = spawner
	_board = board
	_config = config
	_aim_x = config.container_width / 2.0
	_state.current_piece_changed.connect(_on_state_current_piece_changed)


## Apuntado al centro, cooldown 0 y cola nueva. Emite siempre `aim_changed` y
## `drop_ready_changed(true)` para sincronizar a los observadores.
func reset() -> void:
	_aim_x = _config.container_width / 2.0
	_cooldown = 0.0
	_state.set_queue(_generator.next(), _generator.next())
	aim_changed.emit(get_aim_x())
	drop_ready_changed.emit(true)


## Apunta a una X global (la convierte a coordenadas de tablero).
func request_aim_global(global_x: float) -> void:
	_set_aim(_board.to_local(Vector2(global_x, _board.global_position.y)).x)


func request_aim_step(direction: float, delta: float) -> void:
	_set_aim(_aim_x + direction * _config.aim_speed * delta)


## Suelta el ACTUAL (`04` §5). Devuelve `false` si se ignoró.
func request_drop() -> bool:
	if not _state.is_playing() or _cooldown > 0.0:
		return false
	var current: PieceData = _state.get_current_piece()
	if current == null:
		return false
	var x: float = _board.clamp_drop_x(_aim_x, current.radius)
	var piece: Piece = _spawner.spawn(current, Vector2(x, _config.spawn_y), Piece.State.DROPPING)
	_state.advance_queue(_generator.next())
	_cooldown = _config.drop_cooldown
	drop_ready_changed.emit(false)
	piece_dropped.emit(piece)
	return true


func tick(delta: float) -> void:
	if _cooldown <= 0.0:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown == 0.0:
		drop_ready_changed.emit(true)


## X de apuntado limitada con el radio del ACTUAL (o el centro si no hay).
func get_aim_x() -> float:
	var current: PieceData = _state.get_current_piece()
	if current == null:
		return _config.container_width / 2.0
	return _board.clamp_drop_x(_aim_x, current.radius)


func is_drop_ready() -> bool:
	return _cooldown <= 0.0


# Se acota a [0, W] para que mantener pulsada una tecla no acumule distancia
# invisible que luego haya que deshacer.
func _set_aim(x: float) -> void:
	_aim_x = clampf(x, 0.0, _config.container_width)
	aim_changed.emit(get_aim_x())


func _on_state_current_piece_changed(data: PieceData) -> void:
	if data == null:
		return
	aim_changed.emit(get_aim_x())
