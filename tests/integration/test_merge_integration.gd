extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const FixedSpawnStrategy := preload("res://tests/helpers/fixed_spawn_strategy.gd")

var _main: Main
var _config: GameConfig


func before_each() -> void:
	_config = (load("res://game/game_config.tres") as GameConfig).duplicate() as GameConfig
	var fixed := FixedSpawnStrategy.new()
	fixed.level = 1
	_config.spawn_strategy = fixed
	_config.rng_seed = 1234
	_main = (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	_main.config = _config
	_main.records_path = ""
	_main.show_title = false
	add_child_autofree(_main)


func _spawn(level: int, pos: Vector2) -> Piece:
	return _main.get_spawner().spawn(_config.piece_catalog.get_by_level(level), pos, Piece.State.ACTIVE)


func _levels() -> Array[int]:
	var levels: Array[int] = []
	for piece: Piece in _main.get_board().get_pieces():
		levels.append(piece.data.level)
	return levels


func test_two_drops_in_same_column_merge_into_one() -> void:
	var drop: DropSystem = _main.get_drop_system()
	var center_x: float = _main.get_board().global_position.x + _config.container_width / 2.0
	drop.request_aim_global(center_x)
	assert_true(drop.request_drop())
	await wait_physics_frames(40)
	drop.request_aim_global(center_x)
	assert_true(drop.request_drop())
	assert_true(await wait_until(func() -> bool: return _levels() == [2], 3.0),
			"queda exactamente una pieza de nivel 2")
	assert_eq(_main.get_state().get_score(), 3)


func test_cascade_merges_into_level_three() -> void:
	_spawn(2, Vector2(220.0, 578.0))
	_spawn(1, Vector2(220.0, 500.0))
	_spawn(1, Vector2(220.0, 440.0))
	assert_true(await wait_until(func() -> bool: return _levels() == [3], 3.0),
			"cascada hasta una pieza de nivel 3")
	assert_eq(_main.get_state().get_score(), 3 + 6)
