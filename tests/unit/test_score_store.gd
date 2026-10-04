extends GutTest

const PATH: String = "user://test_records.cfg"


func before_each() -> void:
	_remove_file()


func after_each() -> void:
	_remove_file()


func _remove_file() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_initial_best_is_zero() -> void:
	assert_eq(ScoreStore.new(PATH).get_best(), 0)


func test_higher_score_is_a_record_and_persists() -> void:
	var store := ScoreStore.new(PATH)
	watch_signals(store)
	assert_true(store.submit(40))
	assert_eq(store.get_best(), 40)
	assert_signal_emitted_with_parameters(store, "best_changed", [40])
	assert_signal_emitted_with_parameters(store, "new_record", [40])
	assert_eq(ScoreStore.new(PATH).get_best(), 40, "otra instancia lo lee")


func test_lower_or_equal_score_is_not_a_record() -> void:
	var store := ScoreStore.new(PATH)
	store.submit(40)
	watch_signals(store)
	assert_false(store.submit(10))
	assert_false(store.submit(40))
	assert_eq(store.get_best(), 40)
	assert_signal_not_emitted(store, "new_record")
	assert_signal_not_emitted(store, "best_changed")


func test_best_changed_is_emitted_before_new_record() -> void:
	var store := ScoreStore.new(PATH)
	var order: Array[String] = []
	store.best_changed.connect(func(_best: int) -> void: order.append("best"))
	store.new_record.connect(func(_score: int) -> void: order.append("record"))
	store.submit(5)
	assert_eq(order, ["best", "record"] as Array[String])


func test_corrupt_file_is_treated_as_zero() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("esto [no es\n un ConfigFile = = válido")
	file.close()
	var store := ScoreStore.new(PATH)
	assert_eq(store.get_best(), 0)
	assert_true(store.submit(3), "se puede seguir guardando")
	# `ConfigFile` avisa del archivo ilegible al cargarlo y al guardar: es lo esperado.
	assert_engine_error("ConfigFile parse error")
	assert_engine_error("ConfigFile parse error")
	assert_eq(ScoreStore.new(PATH).get_best(), 3, "el archivo se repara al guardar")


func test_unexpected_value_type_is_treated_as_zero() -> void:
	var file := ConfigFile.new()
	file.set_value("records", "best", "mucho")
	file.save(PATH)
	assert_eq(ScoreStore.new(PATH).get_best(), 0)


func test_empty_path_never_touches_disk() -> void:
	var store := ScoreStore.new("")
	assert_true(store.submit(9))
	assert_eq(store.get_best(), 9)
	assert_false(FileAccess.file_exists(PATH))
