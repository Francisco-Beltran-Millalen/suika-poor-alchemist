extends GutTest
## Comprueba que cada asset del Anexo A existe con su tamaño, formato y bucle.

const AssetSpec := preload("res://tools/asset_spec.gd")


func test_every_asset_exists() -> void:
	for entry: Dictionary in AssetSpec.entries():
		assert_ne(AssetSpec.resolve_path(entry), "", "falta %s" % entry["path"])


func test_textures_have_the_specified_size() -> void:
	for entry: Dictionary in AssetSpec.entries():
		if entry["kind"] != "texture":
			continue
		var path: String = entry["path"] as String
		var texture := load(path) as Texture2D
		assert_not_null(texture, "%s carga como Texture2D" % path)
		if texture == null:
			continue
		var expected: Vector2i = entry["size"] as Vector2i
		assert_eq(Vector2i(texture.get_width(), texture.get_height()), expected,
				"tamaño de %s" % path)


func test_audio_loads_and_loops_when_required() -> void:
	for entry: Dictionary in AssetSpec.entries():
		if entry["kind"] != "audio":
			continue
		var path: String = AssetSpec.resolve_path(entry)
		var stream := load(path) as AudioStream
		assert_not_null(stream, "%s carga como AudioStream" % path)
		if stream == null or not (entry["loop"] as bool):
			continue
		assert_true(_loops(stream), "%s tiene el bucle activado" % path)


func test_spec_declares_the_music_with_both_extensions() -> void:
	var music: Array[Dictionary] = []
	for entry: Dictionary in AssetSpec.entries():
		if entry.has("extensions"):
			music.append(entry)
	assert_eq(music.size(), 1, "solo la música admite varias extensiones")
	assert_eq(music[0]["extensions"], ["wav", "ogg"])


func test_spec_has_no_duplicate_paths() -> void:
	var seen: Dictionary = {}
	for entry: Dictionary in AssetSpec.entries():
		assert_false(seen.has(entry["path"]), "duplicado: %s" % entry["path"])
		seen[entry["path"]] = true


func _loops(stream: AudioStream) -> bool:
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	return false
