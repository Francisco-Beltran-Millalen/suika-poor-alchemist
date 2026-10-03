extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const FixedSpawnStrategy := preload("res://tests/helpers/fixed_spawn_strategy.gd")

var _config: GameConfig


func before_each() -> void:
	_config = DataFactory.make_config()


func _make_generator(rng_seed: int) -> PieceGenerator:
	return PieceGenerator.new(_config.piece_catalog, _config.spawn_strategy, rng_seed)


func _sequence(generator: PieceGenerator, count: int) -> Array[int]:
	var levels: Array[int] = []
	for i: int in count:
		levels.append(generator.next().level)
	return levels


func test_same_seed_same_sequence() -> void:
	assert_eq(_sequence(_make_generator(99), 50), _sequence(_make_generator(99), 50))


func test_reset_replays_sequence() -> void:
	var generator: PieceGenerator = _make_generator(99)
	var first: Array[int] = _sequence(generator, 50)
	generator.reset()
	assert_eq(_sequence(generator, 50), first)


func test_zero_seed_is_random_but_valid() -> void:
	var generator: PieceGenerator = _make_generator(0)
	for level: int in _sequence(generator, 100):
		assert_between(level, 1, 5)


func test_set_strategy_changes_distribution() -> void:
	var generator: PieceGenerator = _make_generator(1)
	var fixed := FixedSpawnStrategy.new()
	fixed.level = 3
	generator.set_strategy(fixed)
	for level: int in _sequence(generator, 20):
		assert_eq(level, 3)
