class_name WeightedSpawnStrategy
extends SpawnStrategy
## Elige el nivel `i + 1` con probabilidad proporcional a `weights[i]`.
##
## Un array más corto que el catálogo equivale a peso 0 en los niveles restantes.

@export var weights: PackedFloat32Array = PackedFloat32Array()


func pick(catalog: PieceCatalog, rng: RandomNumberGenerator) -> PieceData:
	return catalog.get_by_level(rng.rand_weighted(weights) + 1)


func validate(catalog: PieceCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	var any_positive: bool = false
	for i: int in weights.size():
		if weights[i] < 0.0:
			errors.append("WeightedSpawnStrategy: weights[%d] es negativo" % i)
		elif weights[i] > 0.0:
			any_positive = true
			if i + 1 >= catalog.size():
				errors.append("WeightedSpawnStrategy: weights[%d] > 0 en el nivel máximo" % i)
	if not any_positive:
		errors.append("WeightedSpawnStrategy: ningún peso es > 0")
	return errors


func get_max_spawn_level(_catalog: PieceCatalog) -> int:
	for i: int in range(weights.size() - 1, -1, -1):
		if weights[i] > 0.0:
			return i + 1
	return 0
