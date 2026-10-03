class_name Main
extends Node
## Composition root: ensambla datos, simulación y presentación.
##
## Es el único lugar que conecta componentes entre sí.

const BOARD_TOP_MARGIN: float = 80.0

@export var config: GameConfig = preload("res://game/game_config.tres")

var _state: GameState
var _generator: PieceGenerator

@onready var _world: Node2D = $World
@onready var _board: Board = $World/Board
@onready var _preview: DropPreview = $World/DropPreview
@onready var _spawner: PieceSpawner = $Systems/PieceSpawner
@onready var _drop_system: DropSystem = $Systems/DropSystem
@onready var _drop_controller: DropController = $DropController


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


func _compose() -> void:
	_state = GameState.new()
	_generator = PieceGenerator.new(config.piece_catalog, config.spawn_strategy, config.rng_seed)
	_update_world_position()
	get_viewport().size_changed.connect(_update_world_position)
	_board.setup(config)
	_spawner.setup(_board.pieces_root)
	_drop_system.setup(_state, _generator, _spawner, _board, config)
	_preview.setup(_state, _drop_system, config)
	_drop_controller.aim_requested.connect(_drop_system.request_aim_global)
	_drop_controller.aim_step_requested.connect(_drop_system.request_aim_step)
	_drop_controller.drop_requested.connect(_drop_system.request_drop)


# Orden de `02` §8.5; se completa en las fases siguientes.
func _start_new_game() -> void:
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
