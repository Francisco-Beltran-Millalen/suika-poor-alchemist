extends RefCounted
## Montaje de test: tablero real + spawner + estado en `PLAYING`. Sin `class_name`.


## Devuelve `{board, spawner, state}`.
static func make(test: GutTest, config: GameConfig) -> Dictionary:
	var board := (load("res://board/board.tscn") as PackedScene).instantiate() as Board
	test.add_child_autofree(board)
	board.setup(config)
	var spawner := PieceSpawner.new()
	test.autofree(spawner)
	spawner.setup(board.pieces_root)
	var state := GameState.new()
	state.start()
	return {"board": board, "spawner": spawner, "state": state}
