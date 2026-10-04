extends GutTest

var _controller: DropController


func before_each() -> void:
	_controller = DropController.new()
	add_child_autofree(_controller)
	watch_signals(_controller)


func after_each() -> void:
	get_tree().paused = false


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_controller._unhandled_input(event)


func test_actions_emit_their_intentions() -> void:
	_press(&"drop")
	_press(&"restart")
	_press(&"toggle_mute")
	_press(&"pause")
	assert_signal_emit_count(_controller, "drop_requested", 1)
	assert_signal_emit_count(_controller, "restart_requested", 1)
	assert_signal_emit_count(_controller, "mute_requested", 1)
	assert_signal_emit_count(_controller, "pause_requested", 1)


func test_while_paused_only_pause_is_emitted() -> void:
	get_tree().paused = true
	_press(&"drop")
	_press(&"restart")
	_press(&"toggle_mute")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300.0, 200.0)
	_controller._unhandled_input(motion)
	assert_signal_not_emitted(_controller, "drop_requested")
	assert_signal_not_emitted(_controller, "restart_requested")
	assert_signal_not_emitted(_controller, "mute_requested")
	assert_signal_not_emitted(_controller, "aim_requested")
	_press(&"pause")
	assert_signal_emit_count(_controller, "pause_requested", 1)


func test_controller_keeps_processing_while_paused() -> void:
	var main := load("res://game/main.tscn") as PackedScene
	var instance := main.instantiate() as Main
	instance.records_path = ""
	instance.show_title = false
	add_child_autofree(instance)
	assert_eq(instance.get_drop_controller().process_mode, Node.PROCESS_MODE_ALWAYS)
