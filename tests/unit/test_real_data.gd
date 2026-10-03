extends GutTest
## Valida los `.tres` reales contra `docs/03_data_design.md` §4.

const EXPECTED: Array[Dictionary] = [
	{"id": &"trash", "radius": 16.0, "score": 1, "rarity": "Común"},
	{"id": &"scrap_metal", "radius": 22.0, "score": 3, "rarity": "Común"},
	{"id": &"copper", "radius": 29.0, "score": 6, "rarity": "Poco común"},
	{"id": &"silver", "radius": 37.0, "score": 10, "rarity": "Raro"},
	{"id": &"gold", "radius": 46.0, "score": 15, "rarity": "Muy raro"},
	{"id": &"enchanted_gold", "radius": 56.0, "score": 21, "rarity": "Épico"},
	{"id": &"celestial_matter", "radius": 68.0, "score": 28, "rarity": "Épico+"},
	{"id": &"philosopher_stone", "radius": 82.0, "score": 36, "rarity": "Legendario"},
]
const SPAWN_PRESETS: Array[String] = [
	"res://piece/spawn/spawn_suika_classic.tres",
	"res://piece/spawn/spawn_uniform_1_4.tres",
	"res://piece/spawn/spawn_weighted.tres",
]

var _catalog: PieceCatalog


func before_each() -> void:
	_catalog = load("res://piece/data/piece_catalog.tres") as PieceCatalog


func test_game_config_is_valid() -> void:
	var config := load("res://game/game_config.tres") as GameConfig
	assert_not_null(config)
	assert_eq(GameConfigValidator.validate(config), PackedStringArray())


func test_catalog_matches_design_table() -> void:
	assert_eq(_catalog.size(), 8)
	for i: int in EXPECTED.size():
		var piece: PieceData = _catalog.pieces[i]
		var expected: Dictionary = EXPECTED[i]
		assert_eq(piece.id, expected["id"])
		assert_eq(piece.level, i + 1)
		assert_eq(piece.radius, expected["radius"], "radio de %s" % piece.id)
		assert_eq(piece.score_value, expected["score"], "score de %s" % piece.id)
		assert_eq(piece.rarity_label, expected["rarity"], "rareza de %s" % piece.id)


func test_catalog_is_valid() -> void:
	assert_eq(PieceCatalogValidator.validate(_catalog), PackedStringArray())


func test_spawn_presets_are_valid() -> void:
	for path: String in SPAWN_PRESETS:
		var strategy := load(path) as SpawnStrategy
		assert_not_null(strategy, path)
		assert_eq(strategy.validate(_catalog), PackedStringArray(), path)


func test_resource_identity_is_shared() -> void:
	for i: int in _catalog.size() - 1:
		assert_same(_catalog.pieces[i].next_piece, _catalog.pieces[i + 1],
				"next_piece de %s es la misma instancia" % _catalog.pieces[i].id)
	assert_null(_catalog.pieces[_catalog.size() - 1].next_piece)
	assert_same(load("res://piece/data/copper.tres"), _catalog.get_by_level(3))


func test_no_embedded_piece_resources() -> void:
	for piece: PieceData in _catalog.pieces:
		var text: String = FileAccess.get_file_as_string(piece.resource_path)
		assert_false(text.contains("[sub_resource"), "%s no incrusta recursos" % piece.id)
