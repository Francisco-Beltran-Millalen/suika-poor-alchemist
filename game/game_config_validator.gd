class_name GameConfigValidator
extends RefCounted
## Validación de un `GameConfig`: catálogo, estrategia y restricciones de `03` §6.


## Devuelve los errores de la configuración; vacío si es válida.
static func validate(config: GameConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if config == null:
		errors.append("config: es null")
		return errors
	if config.piece_catalog == null:
		errors.append("config: piece_catalog es null")
	if config.spawn_strategy == null:
		errors.append("config: spawn_strategy es null")
	if not errors.is_empty():
		return errors
	errors.append_array(PieceCatalogValidator.validate(config.piece_catalog))
	if not errors.is_empty():
		return errors
	errors.append_array(config.spawn_strategy.validate(config.piece_catalog))
	_check_constraints(config, errors)
	return errors


static func _check_constraints(config: GameConfig, errors: PackedStringArray) -> void:
	var catalog: PieceCatalog = config.piece_catalog
	if config.container_width <= 0.0 or config.container_height <= 0.0:
		errors.append("config: el tamaño del recipiente debe ser > 0")
	if config.wall_thickness <= 0.0:
		errors.append("config: wall_thickness debe ser > 0")
	if config.spawn_y <= 0.0:
		errors.append("config: spawn_y debe ser > 0")
	if config.spawn_y >= config.danger_line_y:
		errors.append("config: spawn_y (%s) debe ser < danger_line_y (%s)"
				% [config.spawn_y, config.danger_line_y])
	if config.danger_line_y >= config.container_height:
		errors.append("config: danger_line_y (%s) debe ser < container_height (%s)"
				% [config.danger_line_y, config.container_height])
	var max_spawn: PieceData = catalog.get_by_level(config.spawn_strategy.get_max_spawn_level(catalog))
	if max_spawn != null and config.spawn_y + max_spawn.radius >= config.danger_line_y:
		errors.append("config: spawn_y + radio máximo generable (%s) debe ser < danger_line_y (%s)"
				% [config.spawn_y + max_spawn.radius, config.danger_line_y])
	var max_piece: PieceData = catalog.get_by_level(catalog.get_max_level())
	if 2.0 * max_piece.radius > config.container_width:
		errors.append("config: 2 × radio máximo (%s) supera container_width (%s)"
				% [2.0 * max_piece.radius, config.container_width])
	if config.drop_cooldown < 0.0 or config.game_over_delay < 0.0:
		errors.append("config: drop_cooldown y game_over_delay no pueden ser negativos")
	if config.victory_bonus < 0:
		errors.append("config: victory_bonus no puede ser negativo")
