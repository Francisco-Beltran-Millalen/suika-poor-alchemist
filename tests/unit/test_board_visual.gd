extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")


func _make(layer: BoardVisual.Layer, skin: BoardSkin) -> BoardVisual:
	var visual := BoardVisual.new()
	visual.layer = layer
	visual.skin = skin
	add_child_autofree(visual)
	var rects: Array[Rect2] = [Rect2(-10.0, 0.0, 10.0, 100.0), Rect2(100.0, 0.0, 10.0, 100.0),
			Rect2(-10.0, 100.0, 120.0, 10.0)]
	visual.setup(DataFactory.make_config(), rects)
	return visual


func _square(side: int) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create(side, side, false, Image.FORMAT_RGBA8))


func test_null_skin_draws_the_procedural_fallback_in_both_layers() -> void:
	for layer: BoardVisual.Layer in [BoardVisual.Layer.BACK, BoardVisual.Layer.FRONT]:
		var visual: BoardVisual = _make(layer, null)
		await wait_process_frames(2)
		assert_true(is_instance_valid(visual), "capa %d sin skin" % layer)


func test_skin_without_textures_draws_the_procedural_fallback_in_both_layers() -> void:
	for layer: BoardVisual.Layer in [BoardVisual.Layer.BACK, BoardVisual.Layer.FRONT]:
		var visual: BoardVisual = _make(layer, BoardSkin.new())
		await wait_process_frames(2)
		assert_true(is_instance_valid(visual), "capa %d con skin vacío" % layer)


func test_skin_with_textures_draws_in_both_layers() -> void:
	var skin := BoardSkin.new()
	skin.back_texture = _square(32)
	skin.front_texture = _square(32)
	for layer: BoardVisual.Layer in [BoardVisual.Layer.BACK, BoardVisual.Layer.FRONT]:
		var visual: BoardVisual = _make(layer, skin)
		await wait_process_frames(2)
		assert_true(is_instance_valid(visual), "capa %d con texturas" % layer)


func test_draw_before_setup_does_nothing() -> void:
	var visual := BoardVisual.new()
	add_child_autofree(visual)
	await wait_process_frames(2)
	assert_true(is_instance_valid(visual))
