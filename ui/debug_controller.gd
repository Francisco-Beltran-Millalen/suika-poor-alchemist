class_name DebugController
extends Node
## Traduce las teclas de depuración en intenciones. Solo activo en builds de depuración.

signal strategy_requested(index: int)
signal high_piece_requested
signal overlay_toggled

const _STRATEGY_ACTIONS: Array[StringName] = [
	&"debug_strategy_1", &"debug_strategy_2", &"debug_strategy_3",
]


func _ready() -> void:
	if not OS.is_debug_build():
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	for i: int in _STRATEGY_ACTIONS.size():
		if event.is_action_pressed(_STRATEGY_ACTIONS[i]):
			strategy_requested.emit(i)
			return
	if event.is_action_pressed("debug_high_piece"):
		high_piece_requested.emit()
	elif event.is_action_pressed("debug_overlay"):
		overlay_toggled.emit()
