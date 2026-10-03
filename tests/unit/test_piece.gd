extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")

var _catalog: PieceCatalog


func before_each() -> void:
	_catalog = DataFactory.make_catalog()


func _add_piece(level: int) -> Piece:
	var piece: Piece = DataFactory.make_piece(_catalog.get_by_level(level), Piece.State.ACTIVE)
	add_child_autofree(piece)
	return piece


func _shape_radius(piece: Piece) -> float:
	var node: CollisionShape2D = piece.get_node("CollisionShape2D")
	return (node.shape as CircleShape2D).radius


func test_shape_radius_matches_data() -> void:
	var piece: Piece = _add_piece(3)
	assert_eq(_shape_radius(piece), _catalog.get_by_level(3).radius)
	assert_eq(piece.get_radius(), _catalog.get_by_level(3).radius)


func test_each_piece_has_its_own_shape() -> void:
	var a: Piece = _add_piece(1)
	var b: Piece = _add_piece(1)
	var shape_a: Shape2D = (a.get_node("CollisionShape2D") as CollisionShape2D).shape
	var shape_b: Shape2D = (b.get_node("CollisionShape2D") as CollisionShape2D).shape
	assert_not_same(shape_a, shape_b)
	var c: Piece = _add_piece(5)
	assert_eq(_shape_radius(a), _catalog.get_by_level(1).radius, "crear otra pieza no altera la forma")
	assert_eq(_shape_radius(c), _catalog.get_by_level(5).radius)


func test_mass_derives_from_radius() -> void:
	var piece: Piece = _add_piece(4)
	var expected: float = pow(_catalog.get_by_level(4).radius / 16.0, 2.0)
	assert_almost_eq(piece.mass, expected, 0.0001)


func test_consume() -> void:
	var piece: Piece = _add_piece(1)
	assert_false(piece.is_consumed())
	piece.consume()
	assert_true(piece.is_consumed())
	assert_eq(piece.state, Piece.State.CONSUMED)


func test_initial_state_is_kept() -> void:
	var piece: Piece = DataFactory.make_piece(_catalog.get_by_level(1), Piece.State.DROPPING)
	add_child_autofree(piece)
	assert_eq(piece.state, Piece.State.DROPPING)
