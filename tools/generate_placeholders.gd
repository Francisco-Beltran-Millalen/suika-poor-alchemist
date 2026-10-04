extends SceneTree
## Crea los placeholders de assets que falten (Anexo A de `docs/06_plan_iteracion_2.md`).
##
## Uso:
##   godot --headless -s tools/generate_placeholders.gd            (solo los que faltan)
##   godot --headless -s tools/generate_placeholders.gd -- --force (regenera todos)
##   godot --headless -s tools/generate_placeholders.gd -- --templates
##       (además escribe las plantillas guía para el artista en docs/plantillas/)
##
## Nunca sobrescribe un archivo existente salvo con `--force`.

const AssetSpec := preload("res://tools/asset_spec.gd")
const PlaceholderImages := preload("res://tools/placeholder_images.gd")
const PlaceholderAudio := preload("res://tools/placeholder_audio.gd")
const TEMPLATES_DIR: String = "res://docs/plantillas/"
const PIECE_DATA_DIR: String = "res://piece/data/"
const _COLOR_PATTERN: String = "color = Color\\(([^)]*)\\)"

var _force: bool = false
var _created: int = 0
var _skipped: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_force = args.has("--force")
	for entry: Dictionary in AssetSpec.entries():
		_generate(entry)
	if args.has("--templates"):
		_write_templates()
	print("Resumen: %d creados, %d saltados" % [_created, _skipped])
	quit()


func _generate(entry: Dictionary) -> void:
	var path: String = entry["path"] as String
	if entry.has("extensions"):
		# Placeholder de la música: WAV (Godot no escribe OGG). Si ya hay una
		# versión definitiva en cualquier extensión, no se toca.
		var existing: String = AssetSpec.resolve_path(entry)
		if not existing.is_empty() and not _force:
			_skip(existing)
			return
		path += ".wav"
	elif FileAccess.file_exists(path) and not _force:
		_skip(path)
		return
	if entry["kind"] == "texture":
		_save_image(_make_image(path), path)
	else:
		_save_audio(_make_audio(path), path)


func _make_image(path: String) -> Image:
	var file_name: String = path.get_file().get_basename()
	var piece_index: int = AssetSpec.PIECE_IDS.find(file_name)
	if piece_index >= 0:
		return PlaceholderImages.piece(_piece_color(file_name), piece_index + 1)
	match file_name:
		"workshop_background":
			return PlaceholderImages.workshop_background()
		"jar_back":
			return PlaceholderImages.jar_back()
		"jar_front":
			return PlaceholderImages.jar_front()
		"alchemist_dropper":
			return PlaceholderImages.dropper()
		"parchment_panel":
			return PlaceholderImages.parchment()
	return PlaceholderImages.sparkle()


func _make_audio(path: String) -> AudioStreamWAV:
	match path.get_file().get_basename():
		"sfx_drop":
			return PlaceholderAudio.drop()
		"sfx_merge":
			return PlaceholderAudio.merge()
		"sfx_merge_high":
			return PlaceholderAudio.merge_high()
		"sfx_danger_loop":
			return PlaceholderAudio.danger_loop()
		"sfx_game_over":
			return PlaceholderAudio.game_over()
		"sfx_victory":
			return PlaceholderAudio.victory()
		"sfx_ui_click":
			return PlaceholderAudio.ui_click()
	return PlaceholderAudio.music()


# Se lee del texto del `.tres` y no con `load`: así funciona aunque el material
# ya apunte a un PNG que se está regenerando.
func _piece_color(id: String) -> Color:
	var text: String = FileAccess.get_file_as_string(PIECE_DATA_DIR + id + ".tres")
	var regex := RegEx.create_from_string(_COLOR_PATTERN)
	var found: RegExMatch = regex.search(text)
	if found == null:
		push_warning("%s: sin color en el .tres, se usa gris" % id)
		return Color(0.5, 0.5, 0.5, 1.0)
	var parts: PackedStringArray = found.get_string(1).split(",")
	return Color(parts[0].to_float(), parts[1].to_float(), parts[2].to_float(), 1.0)


func _write_templates() -> void:
	var templates: Dictionary = {
		"plantilla_material_512x512.png": PlaceholderImages.template_piece(),
		"plantilla_workshop_background_2560x1440.png": PlaceholderImages.template_background(),
		"plantilla_jar_back_880x1200.png": PlaceholderImages.template_jar_back(),
		"plantilla_jar_front_1008x1264.png": PlaceholderImages.template_jar_front(),
		"plantilla_alchemist_dropper_256x256.png": PlaceholderImages.template_dropper(),
		"plantilla_parchment_panel_256x256.png": PlaceholderImages.template_parchment(),
		"plantilla_sparkle_64x64.png": PlaceholderImages.template_sparkle(),
	}
	for file_name: String in templates:
		var path: String = TEMPLATES_DIR + file_name
		if FileAccess.file_exists(path) and not _force:
			_skip(path)
			continue
		_save_image(templates[file_name] as Image, path)


func _save_image(image: Image, path: String) -> void:
	_ensure_dir(path)
	var error: Error = image.save_png(ProjectSettings.globalize_path(path))
	_report(path, error)


func _save_audio(stream: AudioStreamWAV, path: String) -> void:
	_ensure_dir(path)
	var error: Error = stream.save_to_wav(ProjectSettings.globalize_path(path))
	_report(path, error)


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))


func _report(path: String, error: Error) -> void:
	if error == OK:
		_created += 1
		print("creado:  ", path)
	else:
		push_error("%s: no se pudo escribir (%s)" % [path, error_string(error)])


func _skip(path: String) -> void:
	_skipped += 1
	print("saltado: ", path, " (ya existe)")
