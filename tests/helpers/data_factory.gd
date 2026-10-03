extends RefCounted
## Fábrica de datos en memoria para tests (sin `.tres`). Sin `class_name`.


## Cadena válida de `levels` materiales con `radius = 10 + 6·level`
## y `score_value = level·(level+1)/2`.
static func make_catalog(levels: int = 8) -> PieceCatalog:
	var catalog := PieceCatalog.new()
	var previous: PieceData = null
	for level: int in range(levels, 0, -1):
		var data := PieceData.new()
		data.id = StringName("piece_%d" % level)
		data.level = level
		data.display_name = "Pieza %d" % level
		data.rarity_label = "Test"
		data.radius = 10.0 + 6.0 * level
		data.score_value = int(level * (level + 1) / 2.0)
		data.color = Color.from_hsv(float(level) / float(levels + 1), 0.6, 0.9)
		data.next_piece = previous
		previous = data
		catalog.pieces.push_front(data)
	return catalog


## Configuración con los valores de `03` §6 y `rng_seed = 1234`.
static func make_config(catalog: PieceCatalog = null) -> GameConfig:
	var config := GameConfig.new()
	config.piece_catalog = catalog if catalog != null else make_catalog()
	var strategy := UniformSpawnStrategy.new()
	strategy.max_level = 5
	config.spawn_strategy = strategy
	config.rng_seed = 1234
	return config


## Pieza lista para `add_child` (con `setup` ya llamado).
static func make_piece(data: PieceData, state: Piece.State) -> Piece:
	var piece := (load("res://piece/piece.tscn") as PackedScene).instantiate() as Piece
	piece.setup(data, state)
	return piece
