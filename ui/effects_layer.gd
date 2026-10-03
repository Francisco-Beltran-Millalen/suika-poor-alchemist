class_name EffectsLayer
extends Node2D
## Efectos visuales: anillo de fusión, advertencia de peligro y victoria.
##
## Solo observa señales; no contiene reglas. Coordenadas de tablero.

const MERGE_RING_DURATION: float = 0.25
const VICTORY_DURATION: float = 1.5
const FLASH_DURATION: float = 0.35
const DANGER_PULSE_SPEED: float = 12.0
const _DANGER_COLOR := Color(0.95, 0.15, 0.2)
const _GOLD := Color(1.0, 0.83, 0.42)
const _RED := Color(0.91, 0.2, 0.24)
const _FLASH_RECT := Rect2(-2000.0, -2000.0, 6000.0, 5000.0)

var _config: GameConfig
var _rings: Array[Ring] = []
var _danger_ratio: float = 0.0
var _time: float = 0.0
var _flash_left: float = 0.0
var _was_active: bool = false


func _process(delta: float) -> void:
	_time += delta
	for ring: Ring in _rings:
		ring.age += delta
	_rings = _rings.filter(func(ring: Ring) -> bool: return ring.age < ring.duration)
	_flash_left = maxf(_flash_left - delta, 0.0)
	var active: bool = _is_active()
	if active or _was_active:
		queue_redraw()
	_was_active = active


func _draw() -> void:
	if _config == null:
		return
	if _danger_ratio > 0.0:
		_draw_danger()
	for ring: Ring in _rings:
		if ring.age >= 0.0:
			_draw_ring(ring)
	if _flash_left > 0.0:
		draw_rect(_FLASH_RECT, Color(1.0, 1.0, 0.85, 0.6 * _flash_left / FLASH_DURATION))


func setup(state: GameState, merge_system: MergeSystem, danger_system: DangerSystem,
		config: GameConfig) -> void:
	_config = config
	state.status_changed.connect(_on_state_status_changed)
	merge_system.pieces_merged.connect(_on_merge_system_pieces_merged)
	merge_system.max_level_merged.connect(_on_merge_system_max_level_merged)
	danger_system.danger_changed.connect(_on_danger_system_danger_changed)


func _is_active() -> bool:
	return _danger_ratio > 0.0 or not _rings.is_empty() or _flash_left > 0.0


func _draw_danger() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * DANGER_PULSE_SPEED)
	var alpha: float = _danger_ratio * pulse
	var line_y: float = _config.danger_line_y
	var band := Color(_DANGER_COLOR, alpha * 0.18)
	draw_rect(Rect2(0.0, line_y - 28.0, _config.container_width, 28.0), band)
	draw_rect(Rect2(0.0, line_y - 3.0, _config.container_width, 6.0), Color(_DANGER_COLOR, alpha))


func _draw_ring(ring: Ring) -> void:
	var t: float = ring.age / ring.duration
	var radius: float = lerpf(ring.start_radius, ring.end_radius, 1.0 - pow(1.0 - t, 2.0))
	var color := Color(ring.color, 1.0 - t)
	draw_arc(ring.position, radius, 0.0, TAU, 48, color, lerpf(5.0, 1.0, t), true)


func _add_ring(position: Vector2, color: Color, start_radius: float, end_radius: float,
		duration: float, delay: float = 0.0) -> void:
	var ring := Ring.new()
	ring.position = position
	ring.color = color
	ring.start_radius = start_radius
	ring.end_radius = end_radius
	ring.duration = duration
	ring.age = -delay
	_rings.append(ring)
	queue_redraw()


func _spawn_victory_particles(position: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = position
	particles.one_shot = true
	particles.amount = 120
	particles.lifetime = 1.2
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 420.0
	particles.gravity = Vector2(0.0, 260.0)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([_GOLD, _RED, Color(_RED, 0.0)])
	particles.color_ramp = ramp
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true


func _clear_effects() -> void:
	_rings.clear()
	_flash_left = 0.0
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	queue_redraw()


func _on_state_status_changed(status: GameState.Status) -> void:
	# Una partida nueva no hereda efectos de la anterior.
	if status == GameState.Status.READY or status == GameState.Status.PLAYING:
		_clear_effects()


func _on_merge_system_pieces_merged(_source: PieceData, result: PieceData, position: Vector2) -> void:
	_add_ring(position, result.color.lightened(0.3), result.radius * 0.8, result.radius * 2.0,
			MERGE_RING_DURATION)


func _on_merge_system_max_level_merged(source: PieceData, position: Vector2) -> void:
	var delays: Array[float] = [0.0, 0.2, 0.4]
	var colors: Array[Color] = [_GOLD, Color.WHITE, _RED]
	for i: int in delays.size():
		_add_ring(position, colors[i], source.radius * 0.8, source.radius * 4.0,
				VICTORY_DURATION - delays[i], delays[i])
	_flash_left = FLASH_DURATION
	_spawn_victory_particles(position)


func _on_danger_system_danger_changed(ratio: float) -> void:
	_danger_ratio = ratio
	queue_redraw()


class Ring extends RefCounted:
	var position: Vector2
	var color: Color
	var start_radius: float
	var end_radius: float
	var duration: float
	var age: float
