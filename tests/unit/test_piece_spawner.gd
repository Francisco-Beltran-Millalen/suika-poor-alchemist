extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")

var _config: GameConfig
var _board: Board
var _spawner: PieceSpawner


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	_board = rig["board"]
	_spawner = rig["spawner"]


func test_spawn_adds_piece_with_position_and_state() -> void:
	watch_signals(_spawner)
	var data: PieceData = _config.piece_catalog.get_by_level(2)
	var piece: Piece = _spawner.spawn(data, Vector2(120.0, 40.0), Piece.State.DROPPING)
	assert_eq(_board.pieces_root.get_child_count(), 1)
	assert_eq(piece.get_parent(), _board.pieces_root)
	assert_eq(piece.position, Vector2(120.0, 40.0))
	assert_eq(piece.state, Piece.State.DROPPING)
	assert_same(piece.data, data)
	assert_signal_emitted_with_parameters(_spawner, "piece_spawned", [piece])


func test_despawn_removes_in_same_frame() -> void:
	var piece: Piece = _spawner.spawn(_config.piece_catalog.get_by_level(1),
			Vector2(100.0, 100.0), Piece.State.ACTIVE)
	_spawner.despawn(piece)
	assert_eq(_board.pieces_root.get_child_count(), 0)
	assert_true(piece.is_queued_for_deletion())


func test_despawn_wakes_remaining_pieces() -> void:
	var catalog: PieceCatalog = _config.piece_catalog
	var removed: Piece = _spawner.spawn(catalog.get_by_level(1), Vector2(100.0, 100.0), Piece.State.ACTIVE)
	var keep_a: Piece = _spawner.spawn(catalog.get_by_level(1), Vector2(200.0, 100.0), Piece.State.ACTIVE)
	var keep_b: Piece = _spawner.spawn(catalog.get_by_level(1), Vector2(300.0, 100.0), Piece.State.ACTIVE)
	# Una pieza recién creada nunca está dormida: se fuerza para que el test
	# falle si `despawn` no despierta nada.
	keep_a.sleeping = true
	keep_b.sleeping = true
	assert_true(keep_a.sleeping and keep_b.sleeping, "precondición")
	_spawner.despawn(removed)
	assert_false(keep_a.sleeping)
	assert_false(keep_b.sleeping)
