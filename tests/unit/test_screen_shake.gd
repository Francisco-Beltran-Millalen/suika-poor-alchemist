extends GutTest

const DataFactory := preload("res://tests/helpers/data_factory.gd")
const BoardRig := preload("res://tests/helpers/board_rig.gd")

var _config: GameConfig
var _merge: MergeSystem
var _target: Node2D


func before_each() -> void:
	_config = DataFactory.make_config()
	var rig: Dictionary = BoardRig.make(self, _config)
	_merge = MergeSystem.new()
	autofree(_merge)
	_merge.setup(rig["state"], rig["spawner"], rig["board"])
	_target = Node2D.new()
	add_child_autofree(_target)
	var shake := ScreenShake.new()
	add_child_autofree(shake)
	shake.setup(_target, _merge)


func _piece(glow: float) -> PieceData:
	var data: PieceData = _config.piece_catalog.get_by_level(3)
	data.glow_strength = glow
	return data


func test_normal_merge_does_not_shake() -> void:
	_merge.pieces_merged.emit(_piece(0.0), _piece(0.0), Vector2.ZERO)
	await wait_process_frames(3)
	assert_eq(_target.position, Vector2.ZERO)


func test_high_merge_shakes_and_settles() -> void:
	var high: PieceData = _piece(PieceVisual.PULSE_MIN_GLOW)
	_merge.pieces_merged.emit(high, high, Vector2.ZERO)
	await wait_process_frames(2)
	assert_ne(_target.position, Vector2.ZERO, "se desplaza")
	assert_true(await wait_until(func() -> bool: return _target.position == Vector2.ZERO, 1.0),
			"vuelve a su sitio")


func test_victory_shakes_harder_than_a_high_merge() -> void:
	var high: PieceData = _piece(PieceVisual.PULSE_MIN_GLOW)
	assert_gt(ScreenShake.VICTORY_INTENSITY, ScreenShake.HIGH_MERGE_INTENSITY)
	_merge.max_level_merged.emit(high, Vector2.ZERO)
	await wait_process_frames(2)
	assert_ne(_target.position, Vector2.ZERO)
