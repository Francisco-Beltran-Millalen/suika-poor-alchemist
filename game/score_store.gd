class_name ScoreStore
extends RefCounted
## Récord local persistido con `ConfigFile`. Sin autoload: lo crea `Main`.

signal best_changed(best: int)
## Emitida por `submit` cuando bate el récord (después de `best_changed`).
signal new_record(score: int)

const _SECTION: String = "records"
const _KEY: String = "best"

var _path: String
var _best: int = 0


## `path` vacío → solo en memoria, nunca escribe a disco.
func _init(path: String) -> void:
	_path = path
	_best = _load()


func get_best() -> int:
	return _best


## Guarda si supera el récord. Devuelve `true` si es un récord nuevo.
func submit(score: int) -> bool:
	if score <= _best:
		return false
	_best = score
	_save()
	best_changed.emit(_best)
	new_record.emit(score)
	return true


# Un archivo ausente, corrupto o con un valor extraño equivale a récord 0.
func _load() -> int:
	if _path.is_empty():
		return 0
	var file := ConfigFile.new()
	if file.load(_path) != OK:
		return 0
	var value: Variant = file.get_value(_SECTION, _KEY, 0)
	return maxi(int(value), 0) if value is int or value is float else 0


func _save() -> void:
	if _path.is_empty():
		return
	var file := ConfigFile.new()
	file.load(_path)
	file.set_value(_SECTION, _KEY, _best)
	var error: Error = file.save(_path)
	if error != OK:
		push_warning("ScoreStore: no se pudo guardar el récord en %s (%s)" % [_path, error_string(error)])
