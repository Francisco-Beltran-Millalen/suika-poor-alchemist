extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")

var _config: GameConfig
var _board: Board


func before_each() -> void:
	_config = DataFactory.make_config()
	_board = (load("res://board/board.tscn") as PackedScene).instantiate() as Board
	add_child_autofree(_board)
	_board.setup(_config)


func _spawn(level: int, pos: Vector2, state: Piece.State) -> Piece:
	var piece: Piece = DataFactory.make_piece(_config.piece_catalog.get_by_level(level), state)
	piece.position = pos
	_board.pieces_root.add_child(piece)
	return piece


func test_dropping_piece_becomes_active_and_rests_on_floor() -> void:
	var piece: Piece = _spawn(2, Vector2(220.0, 40.0), Piece.State.DROPPING)
	var radius: float = piece.get_radius()
	var floor_y: float = _config.container_height - radius
	assert_true(await wait_until(func() -> bool: return piece.state == Piece.State.ACTIVE, 3.0),
			"pasa a ACTIVE")
	await wait_physics_frames(180)
	assert_almost_eq(piece.position.y, floor_y, 2.0, "reposa sobre el suelo")


func test_falling_pieces_emit_contact_detected() -> void:
	var lower: Piece = _spawn(2, Vector2(220.0, 560.0), Piece.State.ACTIVE)
	var upper: Piece = _spawn(2, Vector2(220.0, 300.0), Piece.State.DROPPING)
	watch_signals(upper)
	watch_signals(lower)
	var contacts: Callable = func() -> int:
		return get_signal_emit_count(upper, "contact_detected") \
				+ get_signal_emit_count(lower, "contact_detected")
	assert_true(await wait_until(func() -> bool: return contacts.call() > 0, 3.0),
			"se emite contact_detected")


func test_danger_zone_detects_pieces_above_line() -> void:
	var high: Piece = _spawn(1, Vector2(100.0, 50.0), Piece.State.ACTIVE)
	var low: Piece = _spawn(1, Vector2(300.0, 400.0), Piece.State.ACTIVE)
	for piece: Piece in [high, low]:
		piece.freeze = true
		piece.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	await wait_physics_frames(3)
	var inside: Array[Piece] = _board.danger_zone.get_pieces_inside()
	assert_true(inside.has(high), "incluye la pieza en y = 50")
	assert_false(inside.has(low), "excluye la pieza en y = 400")


func test_cleared_piece_is_not_inside_in_same_frame() -> void:
	var high: Piece = _spawn(1, Vector2(100.0, 50.0), Piece.State.ACTIVE)
	high.freeze = true
	high.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	await wait_physics_frames(3)
	assert_eq(_board.danger_zone.get_pieces_inside().size(), 1, "precondición")
	_board.clear_pieces()
	assert_eq(_board.danger_zone.get_pieces_inside().size(), 0)


func test_frozen_board_keeps_pieces_still() -> void:
	var piece: Piece = _spawn(2, Vector2(220.0, 200.0), Piece.State.ACTIVE)
	await wait_physics_frames(5)
	_board.set_frozen(true)
	await wait_physics_frames(2)
	var frozen_at: Vector2 = piece.position
	await wait_physics_frames(30)
	assert_eq(piece.position, frozen_at)


func test_sleeping_piece_falls_when_support_is_despawned() -> void:
	var spawner := PieceSpawner.new()
	autofree(spawner)
	spawner.setup(_board.pieces_root)
	var support: Piece = spawner.spawn(_config.piece_catalog.get_by_level(5),
			Vector2(220.0, _config.container_height - 46.0), Piece.State.ACTIVE)
	var top: Piece = spawner.spawn(_config.piece_catalog.get_by_level(1),
			Vector2(220.0, _config.container_height - 92.0 - 16.0), Piece.State.ACTIVE)
	await wait_physics_frames(240)
	assert_true(top.sleeping, "precondición: la pieza de arriba duerme")
	spawner.despawn(support)
	await wait_physics_frames(120)
	assert_almost_eq(top.position.y, _config.container_height - top.get_radius(), 3.0,
			"cae hasta el suelo")
