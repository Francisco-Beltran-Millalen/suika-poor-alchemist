class_name SoundSet
extends Resource
## Sonidos del juego (Anexo A.4 de `06`). Todos opcionales: con `null`, silencio.

@export var drop: AudioStream
## Fusión normal; el tono baja con el nivel del resultado.
@export var merge: AudioStream
## Fusión alta (`PieceVisual.is_high_tier`); si es `null`, se usa `merge`.
@export var merge_high: AudioStream
@export var danger_loop: AudioStream
@export var game_over: AudioStream
@export var victory: AudioStream
@export var ui_click: AudioStream
@export var music: AudioStream
