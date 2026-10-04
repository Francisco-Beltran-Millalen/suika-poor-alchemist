class_name DropController
extends Node
## Traduce el input del jugador en intenciones. No conoce reglas.
##
## Procesa también en pausa (`PROCESS_MODE_ALWAYS`), pero entonces solo emite
## `pause_requested`: ni apuntar ni soltar.

signal aim_requested(global_x: float)
signal aim_step_requested(direction: float, delta: float)
signal drop_requested
signal restart_requested
signal mute_requested
signal pause_requested


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var direction: float = Input.get_axis("aim_left", "aim_right")
	if direction != 0.0:
		aim_step_requested.emit(direction, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_requested.emit()
		return
	if get_tree().paused:
		return
	if event is InputEventMouseMotion:
		# Sin Camera2D, las coordenadas del viewport son las globales.
		aim_requested.emit((event as InputEventMouseMotion).position.x)
	elif event.is_action_pressed("drop"):
		drop_requested.emit()
	elif event.is_action_pressed("restart"):
		restart_requested.emit()
	elif event.is_action_pressed("toggle_mute"):
		mute_requested.emit()
