extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")

var _config: GameConfig
var _merge: MergeSystem
var _progress: ProgressSystem
var _effects: EffectsLayer


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	var state: GameState = rig["state"]
	_merge = MergeSystem.new()
	autofree(_merge)
	_merge.setup(state, rig["spawner"], rig["board"])
	_progress = ProgressSystem.new()
	autofree(_progress)
	_progress.setup(state, _config, _merge)
	var danger := DangerSystem.new()
	autofree(danger)
	danger.setup(state, (rig["board"] as Board).danger_zone, _config)
	_effects = EffectsLayer.new()
	add_child_autofree(_effects)
	_effects.setup(state, _merge, danger, _config, _progress)


func test_merge_without_sparkle_texture_spawns_square_particles() -> void:
	assert_null(_effects.sparkle_texture)
	var result: PieceData = _config.piece_catalog.get_by_level(3)
	_merge.pieces_merged.emit(_config.piece_catalog.get_by_level(2), result, Vector2(100.0, 100.0))
	await wait_process_frames(2)
	var particles: Array[Node] = _effects.get_children().filter(
			func(node: Node) -> bool: return node is CPUParticles2D)
	assert_eq(particles.size(), 1)
	assert_null((particles[0] as CPUParticles2D).texture)


func test_particle_count_grows_with_level() -> void:
	_merge.pieces_merged.emit(_config.piece_catalog.get_by_level(1), _config.piece_catalog.get_by_level(2), Vector2.ZERO)
	_merge.pieces_merged.emit(_config.piece_catalog.get_by_level(5), _config.piece_catalog.get_by_level(6), Vector2.ZERO)
	var counts: Array[int] = []
	for child: Node in _effects.get_children():
		if child is CPUParticles2D:
			counts.append((child as CPUParticles2D).amount)
	assert_eq(counts.size(), 2)
	assert_gt(counts[1], counts[0])


func test_points_awarded_shows_and_expires() -> void:
	var result: PieceData = _config.piece_catalog.get_by_level(3)
	_merge.pieces_merged.emit(_config.piece_catalog.get_by_level(2), result, Vector2(100.0, 100.0))
	await wait_process_frames(2)
	assert_eq(_effects._floating_texts.size(), 1, "aparece el texto flotante")
	assert_true(await wait_until(func() -> bool: return _effects._floating_texts.is_empty(),
			EffectsLayer.FLOAT_DURATION + 1.0), "desaparece")


func test_setup_without_progress_system_is_valid() -> void:
	var other := EffectsLayer.new()
	add_child_autofree(other)
	var rig: Dictionary = BoardRig.make(self, _config)
	var danger := DangerSystem.new()
	autofree(danger)
	danger.setup(rig["state"], (rig["board"] as Board).danger_zone, _config)
	other.setup(rig["state"], _merge, danger, _config)
	_merge.pieces_merged.emit(_config.piece_catalog.get_by_level(2), _config.piece_catalog.get_by_level(3), Vector2.ZERO)
	await wait_process_frames(1)
	assert_eq(other._floating_texts.size(), 0)


func test_victory_particles_use_the_sparkle_texture() -> void:
	var sparkle := ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	_effects.sparkle_texture = sparkle
	var catalog: PieceCatalog = _config.piece_catalog
	_merge.max_level_merged.emit(catalog.get_by_level(catalog.get_max_level()), Vector2.ZERO)
	var particles: Array[Node] = _effects.get_children().filter(
			func(node: Node) -> bool: return node is CPUParticles2D)
	assert_eq(particles.size(), 1)
	assert_eq((particles[0] as CPUParticles2D).texture, sparkle)


func test_floating_text_uses_the_theme_font_when_present() -> void:
	assert_eq(_effects._text_font(), ThemeDB.fallback_font, "sin tema")
	_effects.text_theme = Theme.new()
	assert_eq(_effects._text_font(), ThemeDB.fallback_font, "tema sin fuente")
	var font := SystemFont.new()
	_effects.text_theme.default_font = font
	assert_eq(_effects._text_font(), font, "fuente del tema")
