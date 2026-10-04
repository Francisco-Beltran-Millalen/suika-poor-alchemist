class_name Main
extends Node
## Composition root: ensambla datos, simulación y presentación.
##
## Es el único lugar que conecta componentes entre sí.

const BOARD_TOP_MARGIN: float = 80.0

const DEBUG_OVERLAY_INTERVAL: float = 0.25

@export var config: GameConfig = preload("res://game/game_config.tres")
## Presets que F1–F3 activan. Solo se usan en builds de depuración.
@export var debug_strategies: Array[SpawnStrategy] = []

var _state: GameState
var _generator: PieceGenerator
var _debug_strategy_name: String = ""
var _debug_timer: Timer

@onready var _world: Node2D = $World
@onready var _stage: Node2D = $World/Stage
@onready var _board: Board = $World/Stage/Board
@onready var _preview: DropPreview = $World/Stage/DropPreview
@onready var _effects: EffectsLayer = $World/Stage/EffectsLayer
@onready var _spawner: PieceSpawner = $Systems/PieceSpawner
@onready var _drop_system: DropSystem = $Systems/DropSystem
@onready var _merge_system: MergeSystem = $Systems/MergeSystem
@onready var _danger_system: DangerSystem = $Systems/DangerSystem
@onready var _progress_system: ProgressSystem = $Systems/ProgressSystem
@onready var _screen_shake: ScreenShake = $ScreenShake
@onready var _drop_controller: DropController = $DropController
@onready var _ui: GameUI = $GameUI
@onready var _debug_controller: DebugController = $DebugController


func _ready() -> void:
	var errors: PackedStringArray = GameConfigValidator.validate(config)
	if not errors.is_empty():
		for error: String in errors:
			push_error(error)
		return
	_compose()
	_start_new_game()


# Getters de solo lectura para los tests de integración; el juego no los usa.
func get_state() -> GameState:
	return _state


func get_board() -> Board:
	return _board


func get_spawner() -> PieceSpawner:
	return _spawner


func get_drop_system() -> DropSystem:
	return _drop_system


func get_drop_controller() -> DropController:
	return _drop_controller


func get_merge_system() -> MergeSystem:
	return _merge_system


func get_danger_system() -> DangerSystem:
	return _danger_system


func get_ui() -> GameUI:
	return _ui


func get_debug_controller() -> DebugController:
	return _debug_controller


func _compose() -> void:
	_state = GameState.new()
	_debug_strategy_name = config.spawn_strategy.resource_path.get_file().get_basename()
	_generator = PieceGenerator.new(config.piece_catalog, config.spawn_strategy, config.rng_seed)
	_update_world_position()
	get_viewport().size_changed.connect(_update_world_position)
	_board.setup(config)
	_spawner.setup(_board.pieces_root)
	_drop_system.setup(_state, _generator, _spawner, _board, config)
	_merge_system.setup(_state, _spawner, _board)
	_danger_system.setup(_state, _board.danger_zone, config)
	_progress_system.setup(_state, config, _merge_system)
	_preview.setup(_state, _drop_system, config)
	_effects.setup(_state, _merge_system, _danger_system, config, _progress_system)
	_screen_shake.setup(_stage, _merge_system)
	_ui.setup(_state, config.piece_catalog)
	_drop_controller.aim_requested.connect(_drop_system.request_aim_global)
	_drop_controller.aim_step_requested.connect(_drop_system.request_aim_step)
	_drop_controller.drop_requested.connect(_drop_system.request_drop)
	_spawner.piece_spawned.connect(_merge_system.register_piece)
	_state.status_changed.connect(_on_state_status_changed)
	_ui.restart_requested.connect(_on_restart_requested)
	_drop_controller.restart_requested.connect(_on_restart_requested)
	_debug_controller.strategy_requested.connect(_on_debug_strategy_requested)
	_debug_controller.high_piece_requested.connect(_on_debug_high_piece_requested)
	_debug_controller.overlay_toggled.connect(_on_debug_overlay_toggled)
	_debug_timer = Timer.new()
	_debug_timer.wait_time = DEBUG_OVERLAY_INTERVAL
	_debug_timer.timeout.connect(_refresh_debug_overlay)
	add_child(_debug_timer)


# Orden de `02` §8.5. El primer arranque usa la misma función.
func _start_new_game() -> void:
	_merge_system.reset()
	_danger_system.reset()
	_board.clear_pieces()
	_generator.reset()
	_state.reset()
	_drop_system.reset()
	_board.set_frozen(false)
	_state.start()


# Con `stretch/aspect = "expand"` el ancho visible cambia con la ventana.
func _update_world_position() -> void:
	var visible_width: float = get_viewport().get_visible_rect().size.x
	_world.position = Vector2((visible_width - config.container_width) / 2.0, BOARD_TOP_MARGIN)


# La regla de "terminada" vive en `GameState`; aquí solo se congela el tablero.
func _on_state_status_changed(_status: GameState.Status) -> void:
	_board.set_frozen(_state.is_finished())


# Solo se reinicia una partida terminada (la consulta vive en `GameState`).
func _on_restart_requested() -> void:
	if _state.is_finished():
		_start_new_game()


# Depuración: cambiar de estrategia reinicia la partida aunque esté en curso.
func _on_debug_strategy_requested(index: int) -> void:
	if index < 0 or index >= debug_strategies.size():
		return
	var strategy: SpawnStrategy = debug_strategies[index]
	_generator.set_strategy(strategy)
	_start_new_game()
	_debug_strategy_name = strategy.resource_path.get_file().get_basename()
	_ui.set_debug_text("Estrategia: %s" % _debug_strategy_name)


# Pieza de nivel (máximo − 1) para llegar a la victoria en minutos.
func _on_debug_high_piece_requested() -> void:
	var catalog: PieceCatalog = config.piece_catalog
	_state.debug_set_current(catalog.get_by_level(catalog.get_max_level() - 1))


func _on_debug_overlay_toggled() -> void:
	if _debug_timer.is_stopped():
		_debug_timer.start()
		_refresh_debug_overlay()
	else:
		_debug_timer.stop()
		_ui.set_debug_text("")


func _refresh_debug_overlay() -> void:
	_ui.set_debug_text("FPS: %d\nPiezas: %d\nSemilla: %d\nEstrategia: %s" % [
		Engine.get_frames_per_second(), _board.get_pieces().size(),
		config.rng_seed, _debug_strategy_name])
