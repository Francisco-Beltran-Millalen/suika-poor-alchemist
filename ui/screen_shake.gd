class_name ScreenShake
extends Node
## Sacude un nodo (el `Stage`) tras las fusiones altas y, más fuerte, en la victoria.
##
## Las fusiones normales no sacuden. Solo observa señales; el desplazamiento
## decae en `DURATION` y el nodo vuelve siempre a su sitio (también al pausar).

const DURATION: float = 0.25
const HIGH_MERGE_INTENSITY: float = 4.0
const VICTORY_INTENSITY: float = 14.0

var _target: Node2D
var _intensity: float = 0.0
var _time_left: float = 0.0
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	if _target == null or _time_left <= 0.0:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left == 0.0:
		_target.position = Vector2.ZERO
		return
	var strength: float = _intensity * _time_left / DURATION
	_target.position = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * strength


# Pausado no se procesa: sin esto, el escenario quedaría desplazado toda la pausa.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_stop()


func setup(target: Node2D, merge_system: MergeSystem) -> void:
	_target = target
	merge_system.pieces_merged.connect(_on_merge_system_pieces_merged)
	merge_system.max_level_merged.connect(_on_merge_system_max_level_merged)


func _start(intensity: float) -> void:
	_intensity = maxf(_intensity * _time_left / DURATION, intensity)
	_time_left = DURATION


func _stop() -> void:
	_intensity = 0.0
	_time_left = 0.0
	if _target != null:
		_target.position = Vector2.ZERO


func _on_merge_system_pieces_merged(_source: PieceData, result: PieceData, _position: Vector2) -> void:
	if PieceVisual.is_high_tier(result):
		_start(HIGH_MERGE_INTENSITY)


func _on_merge_system_max_level_merged(_source: PieceData, _position: Vector2) -> void:
	_start(VICTORY_INTENSITY)
