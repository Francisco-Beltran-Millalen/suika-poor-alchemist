extends RefCounted
## Lista única de assets esperados (Anexo A de `docs/06_plan_iteracion_2.md`).
##
## Cada entrada: `{"path": String, "kind": "texture" | "audio",
## "size": Vector2i (solo texturas), "loop": bool (solo audio)}`.
## Excepción: la música lleva `path` sin extensión y `"extensions": ["wav", "ogg"]`.
## Sin `class_name`: lo cargan con `preload` el generador y los tests.

const PIECE_IDS: Array[String] = [
	"trash", "scrap_metal", "copper", "silver", "gold",
	"enchanted_gold", "celestial_matter", "philosopher_stone",
]
const PIECES_DIR: String = "res://assets/sprites/pieces/"
const SCENE_DIR: String = "res://assets/sprites/scene/"
const UI_DIR: String = "res://assets/ui/"
const FX_DIR: String = "res://assets/sprites/fx/"
const AUDIO_DIR: String = "res://assets/audio/"
const PIECE_CANVAS: Vector2i = Vector2i(512, 512)


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in PIECE_IDS:
		result.append(_texture(PIECES_DIR + id + ".png", PIECE_CANVAS))
	result.append(_texture(SCENE_DIR + "workshop_background.png", Vector2i(2560, 1440)))
	result.append(_texture(SCENE_DIR + "jar_back.png", Vector2i(880, 1200)))
	result.append(_texture(SCENE_DIR + "jar_front.png", Vector2i(1008, 1264)))
	result.append(_texture(SCENE_DIR + "alchemist_dropper.png", Vector2i(256, 256)))
	result.append(_texture(UI_DIR + "parchment_panel.png", Vector2i(256, 256)))
	result.append(_texture(FX_DIR + "sparkle.png", Vector2i(64, 64)))
	result.append(_audio(AUDIO_DIR + "sfx_drop.wav", false))
	result.append(_audio(AUDIO_DIR + "sfx_merge.wav", false))
	result.append(_audio(AUDIO_DIR + "sfx_merge_high.wav", false))
	result.append(_audio(AUDIO_DIR + "sfx_danger_loop.wav", true))
	result.append(_audio(AUDIO_DIR + "sfx_game_over.wav", false))
	result.append(_audio(AUDIO_DIR + "sfx_victory.wav", false))
	result.append(_audio(AUDIO_DIR + "sfx_ui_click.wav", false))
	var music: Dictionary = _audio(AUDIO_DIR + "bgm_workshop", true)
	music["extensions"] = ["wav", "ogg"]
	result.append(music)
	return result


## Ruta del archivo existente de una entrada (resuelve las `extensions`); `""` si falta.
static func resolve_path(entry: Dictionary) -> String:
	var path: String = entry["path"] as String
	if not entry.has("extensions"):
		return path if FileAccess.file_exists(path) else ""
	for extension: String in entry["extensions"] as Array:
		if FileAccess.file_exists(path + "." + extension):
			return path + "." + extension
	return ""


static func _texture(path: String, size: Vector2i) -> Dictionary:
	return {"path": path, "kind": "texture", "size": size}


static func _audio(path: String, loop: bool) -> Dictionary:
	return {"path": path, "kind": "audio", "loop": loop}
