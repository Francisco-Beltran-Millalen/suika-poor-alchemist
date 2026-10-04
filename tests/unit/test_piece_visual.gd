extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")

var _data: PieceData


func before_each() -> void:
	_data = DataFactory.make_catalog().get_by_level(4)


func _square_texture(side: int = 64) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(side, side, false, Image.FORMAT_RGBA8))


# Las llamadas `draw_*` solo valen dentro de `_draw`: se dibuja desde la señal `draw`.
func _draw_once(data: PieceData) -> bool:
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	var state: Dictionary = {"drawn": false}
	canvas.draw.connect(func() -> void:
		PieceVisual.draw_piece(canvas, data, Vector2.ZERO, 30.0)
		state["drawn"] = true)
	canvas.queue_redraw()
	await wait_process_frames(2)
	return state["drawn"] as bool


func _make_rotated_visual(rotate_texture: bool, with_texture: bool) -> PieceVisual:
	if with_texture:
		_data.texture = _square_texture()
	var holder := Node2D.new()
	holder.rotation = 1.0
	add_child_autofree(holder)
	var visual := PieceVisual.new()
	visual.rotate_texture = rotate_texture
	visual.setup(_data)
	holder.add_child(visual)
	return visual


func test_draw_piece_with_square_texture_does_not_fail() -> void:
	_data.texture = _square_texture()
	assert_true(await _draw_once(_data))


func test_draw_piece_without_texture_still_draws_placeholder() -> void:
	assert_null(_data.texture)
	assert_true(await _draw_once(_data))


func test_texture_stays_upright_when_rotate_texture_is_false() -> void:
	var visual: PieceVisual = _make_rotated_visual(false, true)
	await wait_process_frames(2)
	assert_eq(visual.global_rotation, 0.0)


func test_texture_follows_the_piece_when_rotate_texture_is_true() -> void:
	var visual: PieceVisual = _make_rotated_visual(true, true)
	await wait_process_frames(2)
	assert_almost_eq(visual.global_rotation, 1.0, 0.001)


func test_placeholder_without_texture_stays_upright_regardless_of_flag() -> void:
	var visual: PieceVisual = _make_rotated_visual(true, false)
	await wait_process_frames(2)
	assert_eq(visual.global_rotation, 0.0)
