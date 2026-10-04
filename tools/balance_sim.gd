extends SceneTree
## Simulación headless de balance: dificultad RELATIVA entre estrategias.
##
## Un bot que suelta en una X aleatoria juega partidas completas con cada preset
## de `piece/spawn/`. Mide cuánto aguanta cada estrategia frente a un jugador
## aleatorio; NO mide la diversión ni la dificultad para una persona.
##
## Uso:
##   godot --headless --fixed-fps 60 -s tools/balance_sim.gd -- --games=5
##   opciones: --games=N (semillas por estrategia, 5 por defecto)
##             --max-minutes=M (tope de tiempo simulado por partida, 10 por defecto)
##
## Salida: CSV `estrategia,semilla,resultado,soltadas,nivel_max,puntuacion,segundos`
## y una tabla resumen con medias por estrategia.

const SPAWN_DIR: String = "res://piece/spawn/"
const MAIN_SCENE: PackedScene = preload("res://game/main.tscn")
const FRAME_SECONDS: float = 1.0 / 60.0
# La interfaz y los efectos no aportan nada a la medida: sin proceso, va más rápido.
const PRESENTATION_NODES: Array[String] = ["GameUI", "EffectsLayer", "DropPreview"]

var _games: int = 5
var _max_frames: int = 10 * 60 * 60
var _jobs: Array[Dictionary] = []
var _job_index: int = 0
var _main: Main
var _rng := RandomNumberGenerator.new()
var _frames: int = 0
var _drops: int = 0
var _max_level: int = 1
var _rows: Array[Dictionary] = []
var _started_msec: int = 0


func _initialize() -> void:
	_parse_args()
	_build_jobs()
	_started_msec = Time.get_ticks_msec()
	print("estrategia,semilla,resultado,soltadas,nivel_max,puntuacion,segundos")


func _process(_delta: float) -> bool:
	if _main == null:
		if _job_index >= _jobs.size():
			_print_summary()
			quit()
			return true
		_start_game(_jobs[_job_index])
		return false
	_frames += 1
	var state: GameState = _main.get_state()
	if state.is_finished() or _frames >= _max_frames:
		_finish_game()
		return false
	var drop_system: DropSystem = _main.get_drop_system()
	if drop_system.is_drop_ready():
		var board_x: float = _rng.randf_range(0.0, _main.config.container_width)
		drop_system.request_aim_global(_main.get_board().to_global(Vector2(board_x, 0.0)).x)
		if drop_system.request_drop():
			_drops += 1
	return false


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			_games = maxi(1, arg.get_slice("=", 1).to_int())
		elif arg.begins_with("--max-minutes="):
			_max_frames = maxi(1, int(arg.get_slice("=", 1).to_float() * 60.0 * 60.0))


func _build_jobs() -> void:
	var files: PackedStringArray = DirAccess.get_files_at(SPAWN_DIR)
	files.sort()
	for file: String in files:
		if not file.ends_with(".tres"):
			continue
		var strategy := load(SPAWN_DIR + file) as SpawnStrategy
		if strategy == null:
			continue
		for seed_value: int in range(1, _games + 1):
			_jobs.append({"name": file.get_basename(), "strategy": strategy, "seed": seed_value})


func _start_game(job: Dictionary) -> void:
	var config := (load("res://game/game_config.tres") as GameConfig).duplicate() as GameConfig
	config.spawn_strategy = job["strategy"] as SpawnStrategy
	config.rng_seed = job["seed"] as int
	_main = MAIN_SCENE.instantiate() as Main
	_main.config = config
	for node_name: String in PRESENTATION_NODES:
		var node: Node = _main.find_child(node_name, true, false)
		if node != null:
			node.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(_main)
	_main.get_merge_system().pieces_merged.connect(_on_pieces_merged)
	_rng.seed = job["seed"] as int
	_frames = 0
	_drops = 0
	_max_level = 1


func _on_pieces_merged(_source: PieceData, result: PieceData, _position: Vector2) -> void:
	_max_level = maxi(_max_level, result.level)


func _finish_game() -> void:
	var job: Dictionary = _jobs[_job_index]
	var state: GameState = _main.get_state()
	var result: String = "TIMEOUT"
	match state.get_status():
		GameState.Status.GAME_OVER:
			result = "GAME_OVER"
		GameState.Status.VICTORY:
			result = "VICTORY"
			_max_level = _main.config.piece_catalog.get_max_level()
	var row: Dictionary = {
		"name": job["name"], "seed": job["seed"], "result": result, "drops": _drops,
		"max_level": _max_level, "score": state.get_score(), "seconds": _frames * FRAME_SECONDS,
	}
	_rows.append(row)
	print("%s,%d,%s,%d,%d,%d,%.1f" % [row["name"], row["seed"], result, _drops,
			_max_level, state.get_score(), row["seconds"]])
	root.remove_child(_main)
	_main.free()
	_main = null
	_job_index += 1


func _print_summary() -> void:
	print("\n== Resumen (medias por estrategia, %d partidas cada una) ==" % _games)
	print("%-22s %9s %9s %9s %9s %8s" % ["estrategia", "soltadas", "nivel_max", "puntos", "segundos", "victorias"])
	var names: Array[String] = []
	for row: Dictionary in _rows:
		if not names.has(row["name"] as String):
			names.append(row["name"] as String)
	for strategy_name: String in names:
		var count: int = 0
		var sums: Dictionary = {"drops": 0.0, "max_level": 0.0, "score": 0.0, "seconds": 0.0}
		var victories: int = 0
		for row: Dictionary in _rows:
			if row["name"] != strategy_name:
				continue
			count += 1
			for key: String in sums:
				sums[key] = (sums[key] as float) + (row[key] as float)
			if row["result"] == "VICTORY":
				victories += 1
		print("%-22s %9.1f %9.1f %9.1f %9.1f %5d/%d" % [strategy_name, sums["drops"] / count,
				sums["max_level"] / count, sums["score"] / count, sums["seconds"] / count,
				victories, count])
	print("Tiempo real: %.1f s" % ((Time.get_ticks_msec() - _started_msec) / 1000.0))
	print("Aviso: mide dificultad RELATIVA con un jugador aleatorio, no diversión.")
