class_name PieceData
extends Resource
## Definición inmutable de un tipo de material.
##
## Describe un tipo, no una pieza concreta: diez piezas de Cobre comparten el
## mismo recurso. Nadie lo modifica durante la partida.

@export_group("Identity")
## Identificador único en `snake_case`.
@export var id: StringName = &""
## Nivel en la cadena de fusión (≥ 1, único).
@export var level: int = 1
@export var display_name: String = ""
## Etiqueta de rareza para la leyenda.
@export var rarity_label: String = ""

@export_group("Physics")
## Radio en px. Única fuente de verdad del tamaño físico y visual.
@export var radius: float = 16.0

@export_group("Progression")
## Material resultante de fusionar dos piezas de este tipo (`null` en el máximo).
@export var next_piece: PieceData

@export_group("Scoring")
## Puntos otorgados al crear esta pieza por fusión.
@export var score_value: int = 0

@export_group("Presentation")
@export var color: Color = Color.WHITE
## Opcional. Si es `null` se dibuja un círculo con `color`.
@export var texture: Texture2D
@export_range(0.0, 1.0) var glow_strength: float = 0.0


## Indica si es el último nivel de la cadena.
func is_max_level() -> bool:
	return next_piece == null
