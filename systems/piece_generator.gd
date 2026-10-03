class_name PieceGenerator
extends RefCounted
## Genera el tipo de la próxima pieza. Posee el RNG; la política es la estrategia.

var _catalog: PieceCatalog
var _strategy: SpawnStrategy
var _seed: int = 0
var _rng := RandomNumberGenerator.new()


## `rng_seed == 0` → aleatorio; distinto de 0 → semilla fija.
func _init(catalog: PieceCatalog, strategy: SpawnStrategy, rng_seed: int) -> void:
	_catalog = catalog
	_strategy = strategy
	_seed = rng_seed
	_seed_rng()


## Devuelve el siguiente tipo de pieza según la estrategia.
func next() -> PieceData:
	return _strategy.pick(_catalog, _rng)


## Si hay semilla fija, vuelve a sembrar y reproduce la secuencia desde el principio.
func reset() -> void:
	_seed_rng()


func set_strategy(strategy: SpawnStrategy) -> void:
	_strategy = strategy


func _seed_rng() -> void:
	if _seed == 0:
		_rng.randomize()
	else:
		_rng.seed = _seed
