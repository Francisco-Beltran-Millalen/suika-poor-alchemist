class_name BoardSkin
extends Resource
## Aspecto del recipiente. Todas las texturas son opcionales (Anexo A.2 de `06`).

## Interior del frasco, detrás de las piezas. Escala 2× del interior (880×1200).
@export var back_texture: Texture2D
## Paredes, suelo y reflejos, delante de las piezas. Escala 2× del exterior (1008×1264).
@export var front_texture: Texture2D
@export var danger_color: Color = Color(0.91, 0.2, 0.24, 0.8)
