class_name EffectsLayer
extends Node2D
## Efectos visuales: anillo y partículas de fusión, puntos flotantes,
## advertencia de peligro y victoria.
##
## Solo observa señales; no contiene reglas. Coordenadas de tablero.

const MERGE_RING_DURATION: float = 0.25
const VICTORY_DURATION: float = 1.5
const FLASH_DURATION: float = 0.35
const DANGER_PULSE_SPEED: float = 12.0
const _DANGER_COLOR := Color(0.95, 0.15, 0.2)
const _GOLD := Color(1.0, 0.83, 0.42)
const _RED := Color(0.91, 0.2, 0.24)
const STONE_GROWTH: float = 1.8
const _FLASH_RECT := Rect2(-2000.0, -2000.0, 6000.0, 5000.0)
const FLOAT_DURATION: float = 0.8
const FLOAT_RISE: float = 40.0
const FLOAT_FONT_SIZE: int = 24
const MERGE_PARTICLES_BASE: int = 10
const MERGE_PARTICLES_PER_LEVEL: int = 2
const MERGE_PARTICLES_LIFETIME: float = 0.5

## Textura de las partículas de fusión y victoria. Con `null` se dibujan cuadrados.
@export var sparkle_texture: Texture2D
## Tema de la interfaz: su `default_font` se usa en los puntos flotantes.
## Con `null` o sin fuente, la fuente por defecto de Godot.
@export var text_theme: Theme

var _config: GameConfig
var _rings: Array[Ring] = []
var _floating_texts: Array[FloatingText] = []
var _danger_ratio: float = 0.0
var _time: float = 0.0
var _flash_left: float = 0.0
var _was_active: bool = false
# Piedra fantasma de la victoria: crece y se desvanece sobre el punto de fusión.
var _stone: PieceData
var _stone_position: Vector2 = Vector2.ZERO
var _stone_age: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	for ring: Ring in _rings:
		ring.age += delta
	_rings = _rings.filter(func(ring: Ring) -> bool: return ring.age < ring.duration)
	for text: FloatingText in _floating_texts:
		text.age += delta
	_floating_texts = _floating_texts.filter(
			func(text: FloatingText) -> bool: return text.age < FLOAT_DURATION)
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _stone != null:
		_stone_age += delta
		if _stone_age >= VICTORY_DURATION:
			_stone = null
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
	if _stone != null:
		_draw_stone()
	for text: FloatingText in _floating_texts:
		_draw_floating_text(text)
	if _flash_left > 0.0:
		draw_rect(_FLASH_RECT, Color(1.0, 1.0, 0.85, 0.6 * _flash_left / FLASH_DURATION))


## `progress_system` es opcional: sin él no hay puntos flotantes.
func setup(state: GameState, merge_system: MergeSystem, danger_system: DangerSystem,
		config: GameConfig, progress_system: ProgressSystem = null) -> void:
	_config = config
	if progress_system != null:
		progress_system.points_awarded.connect(_on_progress_system_points_awarded)
	state.status_changed.connect(_on_state_status_changed)
	merge_system.pieces_merged.connect(_on_merge_system_pieces_merged)
	merge_system.max_level_merged.connect(_on_merge_system_max_level_merged)
	danger_system.danger_changed.connect(_on_danger_system_danger_changed)


func _is_active() -> bool:
	return _danger_ratio > 0.0 or not _rings.is_empty() or not _floating_texts.is_empty() \
			or _flash_left > 0.0 or _stone != null


func _draw_danger() -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * DANGER_PULSE_SPEED)
	var alpha: float = _danger_ratio * pulse
	var line_y: float = _config.danger_line_y
	var band := Color(_DANGER_COLOR, alpha * 0.18)
	draw_rect(Rect2(0.0, line_y - 28.0, _config.container_width, 28.0), band)
	draw_rect(Rect2(0.0, line_y - 3.0, _config.container_width, 6.0), Color(_DANGER_COLOR, alpha))


func _draw_stone() -> void:
	var t: float = _stone_age / VICTORY_DURATION
	var scale_factor: float = lerpf(1.0, STONE_GROWTH, 1.0 - pow(1.0 - t, 2.0))
	PieceVisual.draw_piece(self, _stone, _stone_position, _stone.radius * scale_factor, 1.0 - t)


# "+N" sube y se desvanece; centrado en el punto de fusión.
func _draw_floating_text(text: FloatingText) -> void:
	var t: float = text.age / FLOAT_DURATION
	var rise: float = FLOAT_RISE * (1.0 - pow(1.0 - t, 2.0))
	var font: Font = _text_font()
	var label: String = "+%d" % text.amount
	var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT_SIZE).x
	var origin: Vector2 = text.position + Vector2(-width / 2.0, -rise)
	var alpha: float = clampf((1.0 - t) * 2.0, 0.0, 1.0)
	draw_string_outline(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT_SIZE, 4,
			Color(0.0, 0.0, 0.0, alpha * 0.8))
	draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1, FLOAT_FONT_SIZE,
			Color(1.0, 0.95, 0.7, alpha))


func _text_font() -> Font:
	if text_theme != null and text_theme.default_font != null:
		return text_theme.default_font
	return ThemeDB.fallback_font


func _draw_ring(ring: Ring) -> void:
	var t: float = ring.age / ring.duration
	var radius: float = lerpf(ring.start_radius, ring.end_radius, 1.0 - pow(1.0 - t, 2.0))
	var color := Color(ring.color, 1.0 - t)
	draw_arc(ring.center, radius, 0.0, TAU, 48, color, lerpf(5.0, 1.0, t), true)


func _add_ring(center: Vector2, color: Color, start_radius: float, end_radius: float,
		duration: float, delay: float = 0.0) -> void:
	var ring := Ring.new()
	ring.center = center
	ring.color = color
	ring.start_radius = start_radius
	ring.end_radius = end_radius
	ring.duration = duration
	ring.age = -delay
	_rings.append(ring)
	queue_redraw()


# Ráfaga corta con el color del resultado; crece con el nivel.
func _spawn_merge_particles(center: Vector2, result: PieceData) -> void:
	var particles := CPUParticles2D.new()
	particles.position = center
	particles.one_shot = true
	particles.amount = MERGE_PARTICLES_BASE + MERGE_PARTICLES_PER_LEVEL * result.level
	particles.lifetime = MERGE_PARTICLES_LIFETIME
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 60.0 + result.radius * 2.0
	particles.damping_min = 40.0
	particles.damping_max = 80.0
	_apply_sparkle(particles, 1.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	var tint: Color = result.color.lightened(0.35)
	ramp.colors = PackedColorArray([tint, Color(tint, 0.0)])
	particles.color_ramp = ramp
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true


func _spawn_victory_particles(center: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = center
	particles.one_shot = true
	particles.amount = 120
	particles.lifetime = 1.2
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 420.0
	particles.gravity = Vector2(0.0, 260.0)
	_apply_sparkle(particles, 1.75)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	ramp.colors = PackedColorArray([_GOLD, _RED, Color(_RED, 0.0)])
	particles.color_ramp = ramp
	particles.finished.connect(particles.queue_free)
	add_child(particles)
	particles.emitting = true


# Con textura de 64 px, la escala es una fracción; sin ella, son cuadrados de ~1 px.
# `size` multiplica ambas escalas (la victoria usa chispas más grandes).
func _apply_sparkle(particles: CPUParticles2D, size: float) -> void:
	particles.texture = sparkle_texture
	particles.scale_amount_min = (0.15 if sparkle_texture != null else 2.0) * size
	particles.scale_amount_max = (0.35 if sparkle_texture != null else 4.0) * size


func _clear_effects() -> void:
	_rings.clear()
	_floating_texts.clear()
	_flash_left = 0.0
	_stone = null
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	queue_redraw()


func _on_state_status_changed(status: GameState.Status) -> void:
	# Una partida nueva no hereda efectos de la anterior.
	if status == GameState.Status.READY or status == GameState.Status.PLAYING:
		_clear_effects()


func _on_merge_system_pieces_merged(_source: PieceData, result: PieceData, merge_position: Vector2) -> void:
	_add_ring(merge_position, result.color.lightened(0.3), result.radius * 0.8, result.radius * 2.0,
			MERGE_RING_DURATION)
	_spawn_merge_particles(merge_position, result)


func _on_merge_system_max_level_merged(source: PieceData, merge_position: Vector2) -> void:
	var delays: Array[float] = [0.0, 0.2, 0.4]
	var colors: Array[Color] = [source.color.lightened(0.3), Color.WHITE, _GOLD]
	for i: int in delays.size():
		_add_ring(merge_position, colors[i], source.radius * 0.8, source.radius * 4.0,
				VICTORY_DURATION - delays[i], delays[i])
	_flash_left = FLASH_DURATION
	_stone = source
	_stone_position = merge_position
	_stone_age = 0.0
	_spawn_victory_particles(merge_position)


func _on_progress_system_points_awarded(amount: int, award_position: Vector2) -> void:
	var text := FloatingText.new()
	text.amount = amount
	text.position = award_position
	_floating_texts.append(text)
	queue_redraw()


func _on_danger_system_danger_changed(ratio: float) -> void:
	_danger_ratio = ratio
	queue_redraw()


class Ring extends RefCounted:
	var center: Vector2
	var color: Color
	var start_radius: float
	var end_radius: float
	var duration: float
	var age: float


class FloatingText extends RefCounted:
	var amount: int
	var position: Vector2
	var age: float
