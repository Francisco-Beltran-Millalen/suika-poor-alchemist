extends GutTest

const FixedSpawnStrategy := preload("res://tests/helpers/fixed_spawn_strategy.gd")

var _main: Main
var _config: GameConfig


func before_each() -> void:
	_config = (load("res://game/game_config.tres") as GameConfig).duplicate() as GameConfig
	var fixed := FixedSpawnStrategy.new()
	fixed.level = 1
	_config.spawn_strategy = fixed
	_config.rng_seed = 1234
	_main = (load("res://game/main.tscn") as PackedScene).instantiate() as Main
	_main.config = _config
	_main.records_path = ""
	add_child_autofree(_main)


func test_piece_above_line_ends_game_after_delay_and_freezes_board() -> void:
	var piece: Piece = _main.get_spawner().spawn(_config.piece_catalog.get_by_level(2),
			Vector2(220.0, 50.0), Piece.State.ACTIVE)
	piece.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	piece.freeze = true
	await wait_physics_frames(50)
	assert_true(_main.get_state().is_playing(), "aún dentro del retardo")
	await wait_physics_frames(25)
	assert_eq(_main.get_state().get_status(), GameState.Status.GAME_OVER)
	assert_eq(_main.get_board().pieces_root.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_false(_main.get_drop_system().request_drop())


func test_dropped_piece_crossing_the_line_does_not_end_game() -> void:
	assert_true(_main.get_drop_system().request_drop())
	await wait_physics_frames(120)
	assert_true(_main.get_state().is_playing())
