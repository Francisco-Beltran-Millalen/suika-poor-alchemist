extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")

var _catalog: PieceCatalog
var _rng: RandomNumberGenerator


func before_each() -> void:
	_catalog = DataFactory.make_catalog()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 42


func _make_weighted(weights: Array[float]) -> WeightedSpawnStrategy:
	var strategy := WeightedSpawnStrategy.new()
	strategy.weights = PackedFloat32Array(weights)
	return strategy


func test_uniform_only_levels_1_to_5_and_all_appear() -> void:
	var strategy := UniformSpawnStrategy.new()
	strategy.max_level = 5
	var seen: Dictionary = {}
	for i: int in 2000:
		var level: int = strategy.pick(_catalog, _rng).level
		assert_between(level, 1, 5)
		seen[level] = true
	assert_eq(seen.size(), 5, "aparecen los 5 niveles")


func test_weighted_frequencies_match_weights() -> void:
	var weights: Array[float] = [40.0, 25.0, 18.0, 11.0, 6.0]
	var strategy: WeightedSpawnStrategy = _make_weighted(weights)
	var samples: int = 20000
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for i: int in samples:
		counts[strategy.pick(_catalog, _rng).level - 1] += 1
	for i: int in 5:
		var percent: float = 100.0 * counts[i] / samples
		assert_almost_eq(percent, weights[i], 2.0, "nivel %d" % (i + 1))


func test_uniform_validation() -> void:
	var strategy := UniformSpawnStrategy.new()
	strategy.max_level = 5
	assert_eq(strategy.validate(_catalog).size(), 0)
	strategy.max_level = 7
	assert_eq(strategy.validate(_catalog).size(), 0, "7 = máximo - 1 es válido")
	strategy.max_level = 8
	assert_gt(strategy.validate(_catalog).size(), 0, "max_level >= máximo")
	strategy.max_level = 0
	assert_gt(strategy.validate(_catalog).size(), 0)


func test_weighted_validation() -> void:
	var valid: Array[float] = [40.0, 25.0]
	assert_eq(_make_weighted(valid).validate(_catalog).size(), 0)
	var zeros: Array[float] = [0.0, 0.0, 0.0]
	assert_gt(_make_weighted(zeros).validate(_catalog).size(), 0, "todos a 0")
	var empty: Array[float] = []
	assert_gt(_make_weighted(empty).validate(_catalog).size(), 0, "vacío")
	var negative: Array[float] = [10.0, -1.0]
	assert_gt(_make_weighted(negative).validate(_catalog).size(), 0, "negativo")
	var at_max: Array[float] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 5.0]
	assert_gt(_make_weighted(at_max).validate(_catalog).size(), 0, "peso en el nivel máximo")


func test_get_max_spawn_level() -> void:
	var uniform := UniformSpawnStrategy.new()
	uniform.max_level = 4
	assert_eq(uniform.get_max_spawn_level(_catalog), 4)
	var weights: Array[float] = [40.0, 25.0, 0.0, 11.0, 0.0]
	assert_eq(_make_weighted(weights).get_max_spawn_level(_catalog), 4)
	var trailing: Array[float] = [5.0, 0.0, 0.0]
	assert_eq(_make_weighted(trailing).get_max_spawn_level(_catalog), 1)
