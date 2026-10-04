extends RefCounted
## Dibujo de los placeholders de imagen y de las plantillas del artista.
## Solo usa la API de `Image` (funciona en `--headless`). Sin `class_name`.

const BODY_DIAMETER: float = 410.0
const BORDER_WIDTH: float = 8.0
const BRASS := Color(0.72, 0.53, 0.2, 1.0)
# Segmentos de 7 segmentos por dígito: a b c d e f g.
const _SEGMENTS: Dictionary = {
	1: "bc", 2: "abged", 3: "abgcd", 4: "fgbc", 5: "afgcd", 6: "afgecd", 7: "abc", 8: "abcdefg",
}


## Esfera plana de 410 px con borde, reflejo y número de nivel en 7 segmentos.
static func piece(color: Color, level: int) -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var center := Vector2(256.0, 256.0)
	var radius: float = BODY_DIAMETER / 2.0
	var border_color: Color = color.darkened(0.5)
	var shine_center: Vector2 = center + Vector2(-0.45, -0.45) * radius
	for y: int in 512:
		for x: int in 512:
			var point := Vector2(x + 0.5, y + 0.5)
			var distance: float = point.distance_to(center)
			var alpha: float = clampf(radius - distance + 0.5, 0.0, 1.0)
			if alpha <= 0.0:
				continue
			var pixel: Color = border_color if distance > radius - BORDER_WIDTH else color
			var shine: float = clampf((40.0 - point.distance_to(shine_center)) / 6.0, 0.0, 1.0) * 0.4
			pixel = pixel.lerp(Color.WHITE, shine)
			pixel.a = alpha
			image.set_pixel(x, y, pixel)
	var ink: Color = Color.BLACK if color.get_luminance() > 0.45 else Color.WHITE
	_digit(image, level, center, ink)
	return image


static func workshop_background() -> Image:
	var width: int = 2560
	var height: int = 1440
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var top := Color(0.36, 0.23, 0.13)
	var bottom := Color(0.17, 0.1, 0.06)
	for y: int in height:
		var row: Color = top.lerp(bottom, float(y) / float(height))
		image.fill_rect(Rect2i(0, y, width, 1), row)
	var shelf: Color = Color(0.5, 0.34, 0.2)
	for shelf_y: int in [200, 520, 840, 1160]:
		image.fill_rect(Rect2i(0, shelf_y, 700, 30), shelf)
		image.fill_rect(Rect2i(width - 700, shelf_y, 700, 30), shelf)
	# Centro más oscuro y liso: comprueba que el recorte "cubrir" lo deja libre.
	for y: int in height:
		var base: Color = top.lerp(bottom, float(y) / float(height)).darkened(0.45)
		image.fill_rect(Rect2i(775, y, 1010, 1), base)
	return image


static func jar_back() -> Image:
	var image := Image.create(880, 1200, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.1, 0.09, 0.13, 1.0))
	return image


## Paredes y base de 64 px, interior transparente y dos franjas de reflejo.
static func jar_front() -> Image:
	var image := Image.create(1008, 1264, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 64, 1264), BRASS)
	image.fill_rect(Rect2i(944, 0, 64, 1264), BRASS)
	image.fill_rect(Rect2i(0, 1200, 1008, 64), BRASS)
	var gloss := Color(1.0, 1.0, 1.0, 0.1)
	image.fill_rect(Rect2i(120, 40, 36, 1120), gloss)
	image.fill_rect(Rect2i(176, 40, 12, 1120), gloss)
	return image


## Embudo de latón: boca ancha arriba, pico estrecho pegado al borde inferior.
static func dropper() -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y: int in range(40, 200):
		var t: float = float(y - 40) / 160.0
		var half: float = lerpf(100.0, 30.0, t)
		image.fill_rect(Rect2i(int(128.0 - half), y, int(half * 2.0), 1), BRASS)
	image.fill_rect(Rect2i(108, 200, 40, 56), BRASS.darkened(0.2))
	return image


static func parchment() -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.45, 0.32, 0.18, 1.0))
	image.fill_rect(Rect2i(32, 32, 192, 192), Color(0.93, 0.86, 0.68, 1.0))
	return image


## Estrella de cuatro puntas con caída radial de alfa.
static func sparkle() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var radius: float = 31.5
	for y: int in 64:
		for x: int in 64:
			var dx: float = absf(x + 0.5 - 32.0) / radius
			var dy: float = absf(y + 0.5 - 32.0) / radius
			var star: float = clampf(1.0 - (sqrt(dx) + sqrt(dy)), 0.0, 1.0)
			var falloff: float = clampf(1.0 - Vector2(dx, dy).length(), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, minf(star * 1.6, 1.0) * falloff))
	return image


# --- Plantillas para el artista (guías sin texto: leyenda en `docs/07`) ---

## Círculo de 410 px, cruz central y margen sombreado.
static func template_piece() -> Image:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.25, 0.25, 0.25, 1.0))
	var center := Vector2(256.0, 256.0)
	for y: int in 512:
		for x: int in 512:
			var distance: float = Vector2(x + 0.5, y + 0.5).distance_to(center)
			if distance <= BODY_DIAMETER / 2.0:
				image.set_pixel(x, y, Color(0.85, 0.85, 0.85, 1.0))
			if absf(distance - BODY_DIAMETER / 2.0) < 1.5:
				image.set_pixel(x, y, Color(0.1, 0.8, 0.2, 1.0))
	image.fill_rect(Rect2i(0, 255, 512, 2), Color(0.9, 0.2, 0.2, 1.0))
	image.fill_rect(Rect2i(255, 0, 2, 512), Color(0.9, 0.2, 0.2, 1.0))
	return image


## Pared y base opacas; interior transparente marcado con un borde fino.
static func template_jar_front() -> Image:
	var image := jar_front()
	image.fill_rect(Rect2i(64, 0, 880, 4), Color(0.1, 0.8, 0.2, 1.0))
	image.fill_rect(Rect2i(64, 1196, 880, 4), Color(0.1, 0.8, 0.2, 1.0))
	image.fill_rect(Rect2i(64, 0, 4, 1200), Color(0.1, 0.8, 0.2, 1.0))
	image.fill_rect(Rect2i(940, 0, 4, 1200), Color(0.1, 0.8, 0.2, 1.0))
	return image


static func template_jar_back() -> Image:
	var image := Image.create(880, 1200, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.2, 0.3, 1.0))
	image.fill_rect(Rect2i(0, 0, 880, 4), Color(0.1, 0.8, 0.2, 1.0))
	image.fill_rect(Rect2i(0, 1196, 880, 4), Color(0.1, 0.8, 0.2, 1.0))
	return image


## Centro (zona del frasco) marcado: debe ser oscuro y con poco detalle.
static func template_background() -> Image:
	var image := Image.create(2560, 1440, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.3, 0.3, 1.0))
	image.fill_rect(Rect2i(775, 0, 1010, 1440), Color(0.1, 0.1, 0.1, 1.0))
	image.fill_rect(Rect2i(775, 0, 4, 1440), Color(0.9, 0.2, 0.2, 1.0))
	image.fill_rect(Rect2i(1781, 0, 4, 1440), Color(0.9, 0.2, 0.2, 1.0))
	return image


## Borde inferior (donde se apoya la pieza) y eje central.
static func template_dropper() -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.25, 0.25, 0.25, 1.0))
	image.fill_rect(Rect2i(126, 0, 4, 256), Color(0.9, 0.2, 0.2, 1.0))
	image.fill_rect(Rect2i(0, 252, 256, 4), Color(0.1, 0.8, 0.2, 1.0))
	return image


## Esquinas de 32 px (no se deforman) y centro (se estira).
static func template_parchment() -> Image:
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.8, 0.3, 0.3, 1.0))
	image.fill_rect(Rect2i(32, 32, 192, 192), Color(0.3, 0.6, 0.8, 1.0))
	return image


static func template_sparkle() -> Image:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.25, 0.25, 0.25, 1.0))
	image.fill_rect(Rect2i(31, 0, 2, 64), Color(0.9, 0.2, 0.2, 1.0))
	image.fill_rect(Rect2i(0, 31, 64, 2), Color(0.9, 0.2, 0.2, 1.0))
	return image


static func _digit(image: Image, level: int, center: Vector2, ink: Color) -> void:
	var segments: String = _SEGMENTS.get(level, "g") as String
	var width: int = 110
	var height: int = 200
	var thick: int = 28
	var left: int = int(center.x) - width / 2
	var top: int = int(center.y) - height / 2
	var middle: int = top + height / 2 - thick / 2
	var rects: Dictionary = {
		"a": Rect2i(left, top, width, thick),
		"g": Rect2i(left, middle, width, thick),
		"d": Rect2i(left, top + height - thick, width, thick),
		"f": Rect2i(left, top, thick, height / 2),
		"b": Rect2i(left + width - thick, top, thick, height / 2),
		"e": Rect2i(left, top + height / 2, thick, height / 2),
		"c": Rect2i(left + width - thick, top + height / 2, thick, height / 2),
	}
	for segment: String in segments:
		image.fill_rect(rects[segment] as Rect2i, ink)
