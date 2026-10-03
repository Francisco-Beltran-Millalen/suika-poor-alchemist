extends SpawnStrategy
## Estrategia de test: genera siempre el mismo nivel. Sin `class_name`.

@export var level: int = 1


func pick(catalog: PieceCatalog, _rng: RandomNumberGenerator) -> PieceData:
	return catalog.get_by_level(level)


func validate(_catalog: PieceCatalog) -> PackedStringArray:
	return PackedStringArray()


func get_max_spawn_level(_catalog: PieceCatalog) -> int:
	return level
