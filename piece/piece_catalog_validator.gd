class_name PieceCatalogValidator
extends RefCounted
## Validación de un `PieceCatalog` (reglas de `docs/03_data_design.md` §9).


## Devuelve los errores del catálogo; vacío si es válido.
static func validate(catalog: PieceCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog == null:
		errors.append("catálogo: es null")
		return errors
	if catalog.pieces.is_empty():
		errors.append("catálogo: está vacío")
		return errors
	var seen_ids: Dictionary = {}
	var seen_levels: Dictionary = {}
	var count: int = catalog.pieces.size()
	for i: int in count:
		var piece: PieceData = catalog.pieces[i]
		if piece == null:
			errors.append("catálogo: la entrada %d es null" % i)
			continue
		var name: String = str(piece.id) if piece.id != &"" else "entrada %d" % i
		_check_identity(piece, name, i, seen_ids, seen_levels, errors)
		_check_values(piece, name, i, catalog, errors)
		_check_progression(piece, name, i, count, catalog, errors)
	return errors


static func _check_identity(piece: PieceData, name: String, index: int,
		seen_ids: Dictionary, seen_levels: Dictionary, errors: PackedStringArray) -> void:
	if piece.id == &"":
		errors.append("%s: id vacío" % name)
	elif seen_ids.has(piece.id):
		errors.append("%s: id duplicado" % name)
	seen_ids[piece.id] = true
	if seen_levels.has(piece.level):
		errors.append("%s: level %d duplicado" % [name, piece.level])
	seen_levels[piece.level] = true
	if piece.level != index + 1:
		errors.append("%s: level es %d, se esperaba %d" % [name, piece.level, index + 1])


static func _check_values(piece: PieceData, name: String, index: int,
		catalog: PieceCatalog, errors: PackedStringArray) -> void:
	if piece.radius <= 0.0:
		errors.append("%s: radius debe ser > 0" % name)
	elif index > 0:
		var previous: PieceData = catalog.pieces[index - 1]
		if previous != null and piece.radius <= previous.radius:
			errors.append("%s: radius %s no crece respecto al nivel anterior (%s)"
					% [name, piece.radius, previous.radius])
	if piece.score_value < 0:
		errors.append("%s: score_value negativo" % name)
	if piece.glow_strength < 0.0 or piece.glow_strength > 1.0:
		errors.append("%s: glow_strength fuera de [0, 1]" % name)
	if piece.texture != null and piece.texture.get_width() != piece.texture.get_height():
		errors.append("%s: la textura debe ser cuadrada" % name)


static func _check_progression(piece: PieceData, name: String, index: int, count: int,
		catalog: PieceCatalog, errors: PackedStringArray) -> void:
	var is_last: bool = index == count - 1
	if piece.next_piece == null:
		if not is_last:
			errors.append("%s: next_piece es null antes del último nivel" % name)
		return
	if is_last:
		errors.append("%s: next_piece debe ser null en el último nivel" % name)
	if piece.next_piece.level != piece.level + 1:
		errors.append("%s: next_piece.level es %d, se esperaba %d"
				% [name, piece.next_piece.level, piece.level + 1])
	if not catalog.pieces.has(piece.next_piece):
		errors.append("%s: next_piece no pertenece al catálogo" % name)
