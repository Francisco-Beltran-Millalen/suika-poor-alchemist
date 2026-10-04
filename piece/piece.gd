class_name Piece
extends RigidBody2D
## Pieza física del recipiente. Su tamaño sale solo de `data.radius`.

## Emitida en el primer contacto con otra pieza (la recibe `MergeSystem`).
signal contact_detected(piece: Piece, other: Piece)

enum State { DROPPING, ACTIVE, CONSUMED }

## Radio al que corresponde masa 1.
const MASS_REFERENCE_RADIUS: float = 16.0

## Solo lectura por convención: el recurso se comparte entre piezas.
var data: PieceData
var state: State = State.DROPPING

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: PieceVisual = $Visual


func _ready() -> void:
	assert(data != null, "Piece: setup() debe llamarse antes de add_child()")
	# Forma propia por instancia: la del sub-recurso de la escena se comparte.
	var shape := CircleShape2D.new()
	shape.radius = data.radius
	_collision_shape.shape = shape
	mass = pow(data.radius / MASS_REFERENCE_RADIUS, 2.0)
	_visual.setup(data)
	# Las piezas nacidas de una fusión aparecen con rebote (las soltadas, no).
	if state == State.ACTIVE:
		_visual.play_pop_in()
	body_entered.connect(_on_body_entered)


## Debe llamarse ANTES de `add_child()`.
func setup(piece_data: PieceData, initial_state: State) -> void:
	data = piece_data
	state = initial_state


## Marca la pieza como aceptada para una fusión (estado terminal).
func consume() -> void:
	state = State.CONSUMED


func is_consumed() -> bool:
	return state == State.CONSUMED


func get_radius() -> float:
	return data.radius


func _on_body_entered(body: Node) -> void:
	if state == State.DROPPING:
		state = State.ACTIVE
	if body is Piece:
		contact_detected.emit(self, body as Piece)
