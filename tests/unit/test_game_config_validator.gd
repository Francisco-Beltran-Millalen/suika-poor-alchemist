extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error: String in errors:
		if error.contains(fragment):
			return true
	return false


func test_default_config_is_valid() -> void:
	assert_eq(GameConfigValidator.validate(DataFactory.make_config()).size(), 0)


func test_null_config_does_not_crash() -> void:
	assert_gt(GameConfigValidator.validate(null).size(), 0)


func test_null_catalog_reports_error() -> void:
	var config: GameConfig = DataFactory.make_config()
	config.piece_catalog = null
	assert_true(_has_error(GameConfigValidator.validate(config), "piece_catalog es null"))


func test_null_strategy_reports_error() -> void:
	var config: GameConfig = DataFactory.make_config()
	config.spawn_strategy = null
	assert_true(_has_error(GameConfigValidator.validate(config), "spawn_strategy es null"))


func test_invalid_catalog_is_reported() -> void:
	var config: GameConfig = DataFactory.make_config()
	config.piece_catalog.pieces[0].radius = -1.0
	assert_gt(GameConfigValidator.validate(config).size(), 0)


func test_spawn_y_not_below_danger_line() -> void:
	var config: GameConfig = DataFactory.make_config()
	config.spawn_y = 100.0
	assert_true(_has_error(GameConfigValidator.validate(config), "spawn_y (100.0) debe ser < danger_line_y"))


func test_largest_spawnable_piece_crosses_danger_line() -> void:
	var config: GameConfig = DataFactory.make_config()
	# radio de nivel 5 = 40; 40 + 40 = 80 < 100 es válido; con spawn_y = 62 → 102.
	config.spawn_y = 62.0
	assert_true(_has_error(GameConfigValidator.validate(config), "radio máximo generable"))


func test_container_too_narrow_for_largest_piece() -> void:
	var config: GameConfig = DataFactory.make_config()
	config.container_width = 100.0
	assert_true(_has_error(GameConfigValidator.validate(config), "container_width"))


func test_invalid_strategy_is_reported() -> void:
	var config: GameConfig = DataFactory.make_config()
	(config.spawn_strategy as UniformSpawnStrategy).max_level = 8
	assert_true(_has_error(GameConfigValidator.validate(config), "max_level"))
