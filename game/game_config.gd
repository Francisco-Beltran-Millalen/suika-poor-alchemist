class_name GameConfig
extends Resource
## Configuración global de la partida. Inmutable durante la simulación.

@export_group("Board")
## Ancho interior del recipiente (px).
@export var container_width: float = 440.0
## Alto interior del recipiente (px).
@export var container_height: float = 600.0
## Grosor de las paredes (px); paredes gruesas evitan atravesamientos.
@export var wall_thickness: float = 32.0
## Altura de la línea de peligro desde el borde superior del interior (px).
@export var danger_line_y: float = 100.0

@export_group("Spawn")
## Altura desde la que se suelta la pieza (px desde el borde superior).
@export var spawn_y: float = 40.0
## Segundos entre una soltada y la siguiente.
@export var drop_cooldown: float = 0.5
## Velocidad de apuntado con teclado (px/s).
@export var aim_speed: float = 600.0
@export var spawn_strategy: SpawnStrategy
## 0 = aleatorio; distinto de 0 = semilla fija.
@export var rng_seed: int = 0

@export_group("Rules")
## Segundos que una pieza asentada debe seguir sobre la línea para perder.
@export var game_over_delay: float = 1.0
## Puntos por fusionar dos piezas de nivel máximo.
@export var victory_bonus: int = 100

@export_group("Pieces")
@export var piece_catalog: PieceCatalog
