@abstract class_name SpawnStrategy
extends Resource
## Política pura y sin estado que decide qué pieza se genera.
##
## Toda la aleatoriedad sale del `rng` recibido; el estado vive en `PieceGenerator`.


## Devuelve el tipo de pieza a generar.
@abstract func pick(catalog: PieceCatalog, rng: RandomNumberGenerator) -> PieceData


## Devuelve los errores de configuración (vacío si es válida).
@abstract func validate(catalog: PieceCatalog) -> PackedStringArray


## Nivel más alto que puede generar.
@abstract func get_max_spawn_level(catalog: PieceCatalog) -> int
