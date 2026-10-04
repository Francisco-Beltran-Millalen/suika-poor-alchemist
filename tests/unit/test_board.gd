extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")

var _config: GameConfig
var _board: Board


func before_each() -> void:
	_config = DataFactory.make_config()
	_board = (load("res://board/board.tscn") as PackedScene).instantiate() as Board
	add_child_autofree(_board)
	_board.setup(_config)


func _wall(wall_name: String) -> CollisionShape2D:
	return _board.get_node("Walls/%s" % wall_name) as CollisionShape2D


func _assert_wall(wall_name: String, center: Vector2, size: Vector2) -> void:
	var wall: CollisionShape2D = _wall(wall_name)
	assert_eq(wall.position, center, "centro de %s" % wall_name)
	assert_eq((wall.shape as RectangleShape2D).size, size, "tamaño de %s" % wall_name)


func test_walls_match_table() -> void:
	var w: float = _config.container_width
	var h: float = _config.container_height
	var t: float = _config.wall_thickness
	var e: float = Board.WALL_EXTENSION_ABOVE
	_assert_wall("LeftWall", Vector2(-t / 2.0, (h - e) / 2.0), Vector2(t, h + e))
	_assert_wall("RightWall", Vector2(w + t / 2.0, (h - e) / 2.0), Vector2(t, h + e))
	_assert_wall("Floor", Vector2(w / 2.0, h + t / 2.0), Vector2(w + 2.0 * t, t))


func test_setup_twice_does_not_duplicate_walls() -> void:
	_board.setup(_config)
	await wait_physics_frames(1)
	assert_eq(_board.get_node("Walls").get_child_count(), 3)


func test_danger_zone_covers_above_line() -> void:
	var zone: CollisionShape2D = _board.danger_zone.get_node("CollisionShape2D")
	var size: Vector2 = (zone.shape as RectangleShape2D).size
	assert_eq(size, Vector2(_config.container_width, _config.danger_line_y + Board.WALL_EXTENSION_ABOVE))
	assert_almost_eq(zone.position.y - size.y / 2.0, -Board.WALL_EXTENSION_ABOVE, 0.001)
	assert_almost_eq(zone.position.y + size.y / 2.0, _config.danger_line_y, 0.001)


func test_clamp_drop_x() -> void:
	assert_eq(_board.clamp_drop_x(-1000.0, 30.0), 30.0)
	assert_eq(_board.clamp_drop_x(5000.0, 30.0), _config.container_width - 30.0)
	assert_eq(_board.clamp_drop_x(200.0, 30.0), 200.0)


func test_clamp_piece_position() -> void:
	var clamped: Vector2 = _board.clamp_piece_position(Vector2(-5.0, 9999.0), 20.0)
	assert_eq(clamped, Vector2(20.0, _config.container_height - 20.0))
	var inside: Vector2 = _board.clamp_piece_position(Vector2(100.0, 50.0), 20.0)
	assert_eq(inside, Vector2(100.0, 50.0))
	var above: Vector2 = _board.clamp_piece_position(Vector2(100.0, -50.0), 20.0)
	assert_eq(above.y, -50.0, "no se limita por arriba")


func test_clear_pieces_is_immediate() -> void:
	var data: PieceData = _config.piece_catalog.get_by_level(1)
	for i: int in 3:
		_board.pieces_root.add_child(DataFactory.make_piece(data, Piece.State.ACTIVE))
	assert_eq(_board.get_pieces().size(), 3)
	_board.clear_pieces()
	assert_eq(_board.pieces_root.get_child_count(), 0)
	assert_eq(_board.get_pieces().size(), 0)


func test_set_frozen_changes_process_mode() -> void:
	_board.set_frozen(true)
	assert_eq(_board.pieces_root.process_mode, Node.PROCESS_MODE_DISABLED)
	_board.set_frozen(false)
	assert_eq(_board.pieces_root.process_mode, Node.PROCESS_MODE_INHERIT)


func test_visual_layers_surround_the_pieces() -> void:
	var back: Node = _board.get_node("BackVisual")
	var front: Node = _board.get_node("FrontVisual")
	assert_lt(back.get_index(), _board.pieces_root.get_index(), "BackVisual va antes de Pieces")
	assert_gt(front.get_index(), _board.pieces_root.get_index(), "FrontVisual va después de Pieces")
	assert_eq((back as BoardVisual).layer, BoardVisual.Layer.BACK)
	assert_eq((front as BoardVisual).layer, BoardVisual.Layer.FRONT)


# Una sola fuente de geometría: lo dibujado coincide con la colisión.
func test_visual_walls_match_collision_walls() -> void:
	var names: Array[String] = ["LeftWall", "RightWall", "Floor"]
	for visual_name: String in ["BackVisual", "FrontVisual"]:
		var rects: Array[Rect2] = (_board.get_node(visual_name) as BoardVisual)._wall_rects
		assert_eq(rects.size(), names.size(), visual_name)
		for i: int in names.size():
			var wall: CollisionShape2D = _wall(names[i])
			assert_eq(rects[i].get_center(), wall.position, "%s: centro de %s" % [visual_name, names[i]])
			assert_eq(rects[i].size, (wall.shape as RectangleShape2D).size,
					"%s: tamaño de %s" % [visual_name, names[i]])


func test_board_keeps_walls_and_danger_zone_after_refactor() -> void:
	assert_eq(_board.get_node("Walls").get_child_count(), 3)
	assert_not_null(_board.danger_zone)
	assert_not_null(_board.danger_zone.get_node("CollisionShape2D").shape)
