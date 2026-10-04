class_name PieceVisual
extends Node2D
## Dibuja un material: con textura, el sprite sobre su halo; sin ella, un
## círculo placeholder con halo, borde, reflejo y número de nivel.

const HALO_STEPS: int = 4
const HALO_EXPANSION: float = 0.45
const BORDER_WIDTH: float = 2.0
## Desde este `glow_strength` el halo late suavemente.
const PULSE_MIN_GLOW: float = 0.5
const PULSE_AMPLITUDE: float = 0.12
const PULSE_SPEED: float = 2.5
## Los materiales sin brillo (comunes) se ven más opacos y grises.
const DULL_DESATURATION: float = 0.25
const DULL_HIGHLIGHT_ALPHA: float = 0.35
## Fracción del lienzo que ocupa el cuerpo redondo del sprite (Anexo A.1).
## El diámetro físico (2·radius) corresponde a esa fracción; el resto del
## lienzo es margen para destellos y cristales que sobresalen.
const TEXTURE_BODY_FILL: float = 0.8

## Si es false, el sprite se mantiene derecho aunque la pieza ruede
## (la luz pintada en el arte no gira).
@export var rotate_texture: bool = true

var _data: PieceData
var _alpha: float = 1.0


func _process(_delta: float) -> void:
	# Sin textura el número y el reflejo deben quedar derechos aunque la pieza ruede;
	# con textura, solo si el arte lo pide (`rotate_texture`).
	if _data == null:
		return
	var keep_upright: bool = _data.texture == null or not rotate_texture
	if keep_upright and global_rotation != 0.0:
		global_rotation = 0.0
	if _data.glow_strength >= PULSE_MIN_GLOW:
		queue_redraw()


func _draw() -> void:
	if _data != null:
		draw_piece(self, _data, Vector2.ZERO, _data.radius, _alpha)


func setup(data: PieceData) -> void:
	_data = data
	queue_redraw()


func set_alpha(alpha: float) -> void:
	_alpha = alpha
	queue_redraw()


## Dibuja una pieza en `canvas`; también la usan la vista previa y los iconos.
static func draw_piece(canvas: CanvasItem, data: PieceData, center: Vector2,
		radius: float, alpha: float = 1.0) -> void:
	_draw_halo(canvas, data, center, radius, alpha)
	if data.texture != null:
		var side: float = 2.0 * radius / TEXTURE_BODY_FILL
		var half := Vector2(side, side) / 2.0
		canvas.draw_texture_rect(data.texture, Rect2(center - half, half * 2.0), false,
				Color(1.0, 1.0, 1.0, alpha))
		return
	var color: Color = data.color
	if data.glow_strength <= 0.0:
		color.s *= 1.0 - DULL_DESATURATION
	color.a = alpha
	canvas.draw_circle(center, radius, color)
	var border: Color = data.color.darkened(0.35)
	border.a = alpha
	canvas.draw_arc(center, radius, 0.0, TAU, 48, border, BORDER_WIDTH, true)
	var highlight: Color = data.color.lightened(0.5)
	highlight.a = alpha * (DULL_HIGHLIGHT_ALPHA if data.glow_strength <= 0.0 else 1.0)
	canvas.draw_circle(center + Vector2(-0.35, -0.35) * radius, radius * 0.18, highlight)
	_draw_level(canvas, data, center, radius, alpha)


static func _draw_halo(canvas: CanvasItem, data: PieceData, center: Vector2,
		radius: float, alpha: float) -> void:
	if data.glow_strength <= 0.0:
		return
	var halo: Color = data.color.lightened(0.4)
	halo.a = 0.12 * data.glow_strength * alpha
	var pulse: float = 1.0
	if data.glow_strength >= PULSE_MIN_GLOW:
		pulse += PULSE_AMPLITUDE * sin(Time.get_ticks_msec() / 1000.0 * PULSE_SPEED)
	var outer: float = radius * (1.0 + HALO_EXPANSION * data.glow_strength * pulse)
	for step: int in range(HALO_STEPS, 0, -1):
		var ring: float = lerpf(radius, outer, float(step) / HALO_STEPS)
		canvas.draw_circle(center, ring, halo)


static func _draw_level(canvas: CanvasItem, data: PieceData, center: Vector2,
		radius: float, alpha: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(int(radius * 0.7), 10)
	var text_color: Color = Color.BLACK if data.color.get_luminance() > 0.5 else Color.WHITE
	text_color.a = alpha
	var baseline := Vector2(center.x - radius, center.y + font_size * 0.35)
	canvas.draw_string(font, baseline, str(data.level), HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, font_size, text_color)
