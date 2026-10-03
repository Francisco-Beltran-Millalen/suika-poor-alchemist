class_name UniformSpawnStrategy
extends SpawnStrategy
## Elige un nivel uniforme en `[1, max_level]`.

@export_range(1, 16) var max_level: int = 5


func pick(catalog: PieceCatalog, rng: RandomNumberGenerator) -> PieceData:
	return catalog.get_by_level(rng.randi_range(1, max_level))


func validate(catalog: PieceCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if max_level < 1 or max_level > catalog.size() - 1:
		errors.append("UniformSpawnStrategy: max_level %d fuera de [1, %d]"
				% [max_level, catalog.size() - 1])
	return errors


func get_max_spawn_level(_catalog: PieceCatalog) -> int:
	return max_level
