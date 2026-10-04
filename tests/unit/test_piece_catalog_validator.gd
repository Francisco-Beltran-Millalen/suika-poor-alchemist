extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


# Los ciclos de Resource no los libera el conteo de referencias: se rompen al terminar.
func _break_cycles(catalog: PieceCatalog) -> void:
	for piece: PieceData in catalog.pieces:
		piece.next_piece = null


func test_valid_catalog_has_no_errors() -> void:
	assert_eq(PieceCatalogValidator.validate(DataFactory.make_catalog()).size(), 0)


func test_null_and_empty_catalog() -> void:
	assert_gt(PieceCatalogValidator.validate(null).size(), 0)
	assert_gt(PieceCatalogValidator.validate(PieceCatalog.new()).size(), 0)


func test_null_entry() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[2] = null
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "es null"))


func test_empty_id() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[1].id = &""
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "id vacío"))


func test_duplicate_id() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[1].id = catalog.pieces[0].id
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "id duplicado"))


func test_duplicate_level() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[2].level = 2
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "duplicado"))


func test_level_out_of_order() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[2].level = 9
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "se esperaba 3"))


func test_non_positive_radius() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[0].radius = 0.0
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "radius debe ser > 0"))


func test_radius_not_increasing() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[3].radius = catalog.pieces[2].radius
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "no crece"))


func test_negative_score() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[0].score_value = -1
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "score_value negativo"))


func test_glow_out_of_range() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[0].glow_strength = 1.5
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "glow_strength"))
	catalog.pieces[0].glow_strength = -0.1
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "glow_strength"))


func test_null_next_piece_before_end() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[2].next_piece = null
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "antes del último nivel"))


func test_non_null_next_piece_at_end() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[7].next_piece = catalog.pieces[0]
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "debe ser null en el último"))
	_break_cycles(catalog)


func test_level_jump() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[1].next_piece = catalog.pieces[3]
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "next_piece.level es 4, se esperaba 3"))


func test_self_reference() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[1].next_piece = catalog.pieces[1]
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "next_piece.level"))
	_break_cycles(catalog)


func test_next_piece_outside_catalog() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	var outsider := PieceData.new()
	outsider.id = &"outsider"
	outsider.level = 3
	outsider.radius = 99.0
	catalog.pieces[1].next_piece = outsider
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "no pertenece al catálogo"))


func test_non_square_texture_is_an_error() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[0].texture = ImageTexture.create_from_image(
			Image.create(64, 32, false, Image.FORMAT_RGBA8))
	assert_true(_has_error(PieceCatalogValidator.validate(catalog), "la textura debe ser cuadrada"))
	_break_cycles(catalog)


func test_square_or_null_texture_is_valid() -> void:
	var catalog: PieceCatalog = DataFactory.make_catalog()
	catalog.pieces[0].texture = ImageTexture.create_from_image(
			Image.create(64, 64, false, Image.FORMAT_RGBA8))
	assert_eq(PieceCatalogValidator.validate(catalog).size(), 0)
	_break_cycles(catalog)
