# Plan de implementación (guía paso a paso)

Guía **temporal** para el agente que escriba el código de El Alquimista
Pobre. Se sigue de arriba abajo, una fase cada vez. Cada fase incluye el
contrato (API exacta) de los archivos que crea, los pasos, los tests y el
commit.

Este documento no es diseño permanente. El diseño está en `01`–`04` y en
`el_alquimista_pobre_concepto.md`; si el plan y el diseño discrepan, manda el
diseño y la discrepancia se anota en la sección "Desviaciones" del final.

---

## Paso previo — Reglas para el agente

1. Lee en este orden: `RULES.md`, `04_gameplay_design.md`,
   `03_data_design.md`, `02_technical_design.md` y esta guía completa.
2. **Una fase cada vez.** No empieces la siguiente con tests en rojo.
3. Las firmas de esta guía son contrato. Puedes añadir métodos privados
   (`_x`), pero no cambiar ni añadir API pública sin anotarlo en
   "Desviaciones" en el mismo commit.
4. Si encuentras una contradicción o algo imposible en el motor,
   **detente**, elige la alternativa más simple que respete el diseño y
   anótala en "Desviaciones" con su motivo.
5. Tipado estático en todo. Orden interno de script según `RULES.md` §4.
   Doc comments `##` en toda la API pública.
6. **Ningún archivo de código puede superar las 400 líneas.**
7. Al cerrar cada fase:
   1. `godot --headless --path . --import` (si añadiste `class_name` o
      recursos);
   2. la suite completa de GUT, en verde;
   3. el commit con el mensaje indicado.

### Comandos

```bash
godot --headless --path . --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --path . --scene res://game/main.tscn
godot --path . --scene res://game/main.tscn --write-movie /tmp/mov/shot.png --fixed-fps 60 --quit-after 240
```

### Convenciones transversales

- **Conexiones:**
  - Cada componente **se suscribe él mismo**, dentro de su `setup()`, a las
    señales que observa (p. ej. `state.score_changed.connect(_on_state_score_changed)`).
  - `Main` solo conecta tres cosas: las intenciones de la presentación hacia
    los sistemas (`DropController` → `DropSystem`), `piece_spawned` →
    `MergeSystem.register_piece`, y sus propios callbacks.
- **Coordenadas:** toda posición de la simulación está en coordenadas de
  tablero (origen en la esquina superior izquierda del interior, Y hacia
  abajo). Ver `02` §5.
- **Tiempo:** los sistemas con lógica temporal exponen un `tick(delta)`
  público, llamado desde `_physics_process`. Los tests unitarios lo llaman
  directamente.
- **Cola vacía:** `GameState.reset()` emite `current_piece_changed(null)` y
  `next_piece_changed(null)`. **Todo observador de esas señales debe aceptar
  `null`** (no dibujar, no limitar) y tiene un test que lo comprueba.
- **Ayudas de test:** van en `tests/helpers/`, **sin `class_name`**, y se
  cargan con `preload(...)`. **Ningún helper puede empezar por `test_`**,
  porque GUT lo intentaría cargar como test. Cada helper se crea en la
  primera fase en la que existen las clases que usa.
- **Arrays tipados:** los `Array[T]` se construyen como
  `var xs: Array[T] = []` + `append`. Nunca asignes un literal sin tipo ni
  devuelvas un `Array` genérico desde una función `-> Array[T]`: falla en
  tiempo de ejecución. La cola de fusiones es `Array[Array]`, o mejor dos
  `Array[Piece]` paralelos.
- **Esperas en tests:** `wait_until` de GUT **no falla** al agotar el tiempo,
  solo devuelve `false`. Úsalo siempre como
  `assert_true(await wait_until(func() -> bool: return …, 3.0), "mensaje")`.
  Para medir duraciones de simulación, cuenta frames de física
  (`await wait_physics_frames(n)`) en lugar de segundos de reloj.
- **Reinicio y emisiones incondicionales:** los métodos `reset()`
  (`GameState`, `DangerSystem`, `DropSystem`) emiten sus señales **siempre**,
  como excepción explícita a la regla de "solo si cambia". Así los
  observadores se sincronizan tras un reinicio.
- **El código de una fase solo referencia clases que ya existen.** Los
  nodos de `main.tscn`, sus getters y sus `setup()` se añaden en la fase
  que crea su clase.
- **Config de los tests de integración:** `var cfg := load("res://game/game_config.tres").duplicate()`
  y se le reemplaza `spawn_strategy` (p. ej. por `FixedSpawnStrategy`) y
  `rng_seed`. Así el catálogo real (con `philosopher_stone`) está disponible.
  Se asigna a `main.config` **antes** de `add_child`.

---

## Fase 0 — Configuración del proyecto

**Objetivo:** dejar el proyecto listo (renderer, capas, input) y la
infraestructura de tests.

**Pasos**

1. En `project.godot`:
   - corrige `config/features` a `PackedStringArray("4.7", "GL Compatibility")`,
     coherente con `renderer/rendering_method="gl_compatibility"`;
   - añade los nombres de capas: `[layer_names]`,
     `2d_physics/layer_1="walls"`, `2d_physics/layer_2="pieces"`;
   - añade el InputMap (`[input]`):

     | Acción      | Eventos                                            |
     | ----------- | -------------------------------------------------- |
     | `aim_left`  | A (physical_keycode 65), ← (4194319)               |
     | `aim_right` | D (68), → (4194321)                                |
     | `drop`      | Espacio (32), botón izquierdo del ratón (button_index 1) |
     | `restart`   | R (82)                                             |

     Si escribir el bloque `[input]` a mano da problemas, créalo una vez
     desde el editor o con un script y copia el resultado.
2. En `README.md`, la fila "Motor" pone "Forward+ / GL Compatibility"; debe
   decir solo "GL Compatibility".
3. Crea la carpeta `tests/helpers/` (vacía, con `.gitkeep`). Los helpers se
   crean más adelante, en la fase indicada:
   - `data_factory.gd` (fase 1; `make_piece` en la fase 3): funciones
     estáticas que construyen datos en memoria, sin `.tres`:
     - `make_catalog(levels: int = 8) -> PieceCatalog`: cadena válida con
       `radius = 10 + 6·level` y `score_value = level·(level+1)/2`;
     - `make_config(catalog: PieceCatalog = null) -> GameConfig`: los valores
       de `03` §6 con `rng_seed = 1234`;
     - `make_piece(data: PieceData, state: Piece.State) -> Piece` (fase 3).
   - `fixed_spawn_strategy.gd` (fase 1): extiende `SpawnStrategy`, con
     `@export var level: int = 1`. Implementa **los tres** métodos
     abstractos: `pick` → `catalog.get_by_level(level)`; `validate` →
     vacío; `get_max_spawn_level` → `level`.
   - `stub_danger_zone.gd` (fase 3): extiende `DangerZone`, con
     `var pieces: Array[Piece]` y un `get_pieces_inside()` sobrescrito que la
     devuelve.
   - `board_rig.gd` (fase 4): `static func make(test: GutTest, config: GameConfig) -> Dictionary`.
     Instancia `board.tscn` con `test.add_child_autofree` (los `@onready`
     necesitan el árbol), llama a `board.setup(config)`, crea un
     `PieceSpawner` (`setup(board.pieces_root)`) y un `GameState` ya en
     `PLAYING`. Devuelve `{board, spawner, state}`. Lo usan los tests
     unitarios de `DropSystem`, `MergeSystem` y la física.
4. Comprueba que `test_smoke.gd` pasa.

**Hecho cuando:** el proyecto importa sin errores y GUT pasa.

**Commit:** `feat(proyecto): configuración de renderer, capas físicas e input map`

---

## Fase 1 — Datos

**Objetivo:** todos los `Resource` del juego, con su validación.

### Contrato

```gdscript
# piece/piece_data.gd
class_name PieceData
extends Resource
## Definición inmutable de un tipo de material.
@export_group("Identity")
@export var id: StringName = &""
@export var level: int = 1
@export var display_name: String = ""
@export var rarity_label: String = ""
@export_group("Physics")
@export var radius: float = 16.0
@export_group("Progression")
@export var next_piece: PieceData
@export_group("Scoring")
@export var score_value: int = 0
@export_group("Presentation")
@export var color: Color = Color.WHITE
@export var texture: Texture2D
@export_range(0.0, 1.0) var glow_strength: float = 0.0
func is_max_level() -> bool                  # next_piece == null

# piece/piece_catalog.gd
class_name PieceCatalog
extends Resource
@export var pieces: Array[PieceData] = []
func get_by_level(level: int) -> PieceData   # null si está fuera de rango
func get_max_level() -> int                  # pieces.size()
func size() -> int

# piece/piece_catalog_validator.gd
class_name PieceCatalogValidator
extends RefCounted
static func validate(catalog: PieceCatalog) -> PackedStringArray   # reglas de 03 §9

# game/game_config_validator.gd
class_name GameConfigValidator
extends RefCounted
static func validate(config: GameConfig) -> PackedStringArray
# = catálogo + config.spawn_strategy.validate(catálogo) + restricciones de 03 §6
# Si piece_catalog o spawn_strategy son null, lo reporta como error y no sigue.

# piece/spawn/spawn_strategy.gd
@abstract class_name SpawnStrategy
extends Resource
@abstract func pick(catalog: PieceCatalog, rng: RandomNumberGenerator) -> PieceData
@abstract func validate(catalog: PieceCatalog) -> PackedStringArray
@abstract func get_max_spawn_level(catalog: PieceCatalog) -> int

# piece/spawn/uniform_spawn_strategy.gd
class_name UniformSpawnStrategy extends SpawnStrategy
@export_range(1, 16) var max_level: int = 5
# pick: catalog.get_by_level(rng.randi_range(1, max_level))

# piece/spawn/weighted_spawn_strategy.gd
class_name WeightedSpawnStrategy extends SpawnStrategy
@export var weights: PackedFloat32Array = PackedFloat32Array()
# pick: catalog.get_by_level(rng.rand_weighted(weights) + 1)
# get_max_spawn_level: el índice más alto con peso > 0, más 1
```

- `game/game_config.gd`: los campos, grupos y valores de `03` §6, con
  `@export_group` (`Board`, `Spawn`, `Rules`, `Pieces`). Sin métodos.
- Los mensajes de validación identifican el recurso, por ejemplo:
  `"copper: next_piece.level es 5, se esperaba 4"`.
- `@abstract` y `rand_weighted` están verificados en Godot 4.7.2.

### Pasos

1. Escribe las clases del contrato.
2. Crea los presets de generación en `piece/spawn/`:

   | Preset                     | Clase                   | Parámetros                     |
   | -------------------------- | ----------------------- | ------------------------------ |
   | `spawn_suika_classic.tres` | `UniformSpawnStrategy`  | `max_level = 5`                |
   | `spawn_uniform_1_4.tres`   | `UniformSpawnStrategy`  | `max_level = 4`                |
   | `spawn_weighted.tres`      | `WeightedSpawnStrategy` | `weights = [40, 25, 18, 11, 6]` |

3. Crea los 8 materiales en `piece/data/` (`trash`, `scrap_metal`, `copper`,
   `silver`, `gold`, `enchanted_gold`, `celestial_matter`,
   `philosopher_stone`) con los valores **exactos** de `03` §4, más
   `piece_catalog.tres`. Recomendación: escríbelos desde el último
   (`next_piece = null`) hacia el primero, para que cada `ext_resource` ya
   exista. Alternativa: un script desechable `godot --headless -s` que los
   construya con `ResourceSaver.save()`. Ese script no se commitea, y debe
   **guardar cada recurso en su `.tres` y recargarlo con `load()` antes de
   asignarlo como `next_piece` o meterlo en el catálogo**; si no, se
   incrustan copias como `sub_resource` y se rompe la identidad.
   **Ningún `.tres` de datos puede contener `[sub_resource type="Resource"`**:
   todas las referencias entre materiales son `ext_resource`.
4. Crea `game/game_config.tres` con los valores de `03` §6, apuntando a
   `spawn_suika_classic.tres` y a `piece_catalog.tres`.
5. Crea `tests/helpers/data_factory.gd` (`make_catalog`, `make_config`) y
   `tests/helpers/fixed_spawn_strategy.gd`.

### Tests (`tests/unit/`)

- `test_piece_catalog_validator.gd`:
  - el catálogo de `make_catalog()` es válido;
  - un caso por cada regla de `03` §9: id vacío, id duplicado, nivel
    duplicado, radio no creciente, score negativo, glow fuera de rango,
    `next_piece` nulo antes del final, no nulo al final, salto de nivel,
    autorreferencia, pieza fuera del catálogo.
- `test_spawn_strategies.gd`:
  - `Uniform(5)` con 2000 muestras: solo niveles 1–5 y todos aparecen;
  - `Weighted [40,25,18,11,6]` con 20 000 muestras: cada frecuencia a ±2
    puntos porcentuales del peso normalizado;
  - la validación rechaza `max_level ≥ máximo`, pesos todos a 0, pesos
    negativos y peso > 0 en el nivel máximo;
  - `get_max_spawn_level` es correcto en ambas clases.
- `test_game_config_validator.gd`:
  - `make_config()` es válida;
  - `piece_catalog = null` o `spawn_strategy = null` → error, sin crash;
  - detecta `spawn_y ≥ danger_line_y`, `spawn_y + r_max_generable ≥ danger_line_y`,
    `2·r_max > container_width` y una estrategia inválida.
- `test_real_data.gd` (carga los `.tres` reales):
  - `game_config.tres` pasa el validador;
  - el catálogo tiene 8 piezas con ids, radios, puntuaciones y rarezas
    idénticos a `03` §4;
  - los tres presets son válidos;
  - **identidad de recursos:** `catalog.pieces[i].next_piece == catalog.pieces[i + 1]`
    (misma instancia) y `load("res://piece/data/copper.tres") == catalog.get_by_level(3)`.
    Sin esto, la fusión `a.data == b.data` fallaría en silencio.

**Commit:** `feat(datos): PieceData, catálogo, estrategias de generación y GameConfig con validación`

---

## Fase 2 — Estado y generación

**Objetivo:** el estado lógico de la partida y el generador de piezas, sin
nodos.

### Contrato

```gdscript
# game/game_state.gd
class_name GameState
extends RefCounted
signal score_changed(score: int)
signal current_piece_changed(data: PieceData)
signal next_piece_changed(data: PieceData)
signal status_changed(status: Status)
enum Status { READY, PLAYING, GAME_OVER, VICTORY }
func get_score() -> int
func get_status() -> Status
func get_current_piece() -> PieceData
func get_next_piece() -> PieceData
func is_playing() -> bool
func is_finished() -> bool                   # GAME_OVER o VICTORY (Main lo usa para congelar y reiniciar)
func start() -> bool                         # READY → PLAYING; false si no está en READY
func add_score(amount: int) -> void          # ignora si no está PLAYING; assert(amount >= 0)
func set_queue(current: PieceData, next: PieceData) -> void
func advance_queue(new_next: PieceData) -> PieceData   # devuelve el ACTUAL saliente
func set_game_over() -> bool                 # solo desde PLAYING
func set_victory() -> bool                   # solo desde PLAYING
func reset() -> void                         # score 0, cola null, READY

# systems/piece_generator.gd
class_name PieceGenerator
extends RefCounted
func _init(catalog: PieceCatalog, strategy: SpawnStrategy, rng_seed: int) -> void
func next() -> PieceData
func reset() -> void            # si rng_seed != 0, vuelve a sembrar con la misma semilla
func set_strategy(strategy: SpawnStrategy) -> void
```

- `score_changed` y `status_changed` se emiten **solo si el valor cambia**
  (salvo en `reset()`).
- `current_piece_changed` y `next_piece_changed` se emiten **siempre** en
  `set_queue` y `advance_queue`, aunque el recurso sea el mismo. El
  generador repite tipos a menudo, y los observadores deben enterarse de
  cada avance de la cola.
- `reset()` emite las cuatro siempre.
- `rng_seed == 0` → `rng.randomize()`.

### Tests

- `test_game_state.gd`:
  - tabla de transiciones de `04` §15: las válidas devuelven `true` y emiten
    `status_changed` una vez; las inválidas devuelven `false` y no emiten
    (`watch_signals`, `assert_signal_emit_count`);
  - `add_score` suma y emite solo en `PLAYING`;
  - `advance_queue` devuelve el ACTUAL saliente, desplaza la cola y emite
    ambas señales, **también cuando el nuevo valor es el mismo recurso**;
  - `reset` deja score 0, cola nula y `READY`, y emite las 4 señales.
- `test_piece_generator.gd`:
  - con la misma semilla, dos generadores producen la misma secuencia de 50;
  - `reset()` reproduce la secuencia desde el principio;
  - `set_strategy(FixedSpawnStrategy(3))` → `next()` siempre devuelve
    nivel 3.

**Commit:** `feat(estado): GameState con transiciones validadas y PieceGenerator con semilla`

---

## Fase 3 — Pieza y tablero

**Objetivo:** las entidades físicas y el recipiente, construidos desde la
configuración.

### Contrato

```gdscript
# piece/piece.gd
class_name Piece
extends RigidBody2D
signal contact_detected(piece: Piece, other: Piece)
enum State { DROPPING, ACTIVE, CONSUMED }
const MASS_REFERENCE_RADIUS: float = 16.0
var data: PieceData            # solo lectura por convención
var state: State = State.DROPPING
func setup(piece_data: PieceData, initial_state: State) -> void   # se llama ANTES de add_child
func consume() -> void         # state = CONSUMED
func is_consumed() -> bool
func get_radius() -> float
# _ready: crea un CircleShape2D.new() propio con data.radius; mass = (radius / 16)²;
#         $Visual.setup(data); body_entered.connect(_on_body_entered)
# _on_body_entered(body): si DROPPING → ACTIVE; si body es Piece → contact_detected.emit(self, body)

# piece/piece_visual.gd
class_name PieceVisual
extends Node2D
func setup(data: PieceData) -> void
func set_alpha(alpha: float) -> void
static func draw_piece(canvas: CanvasItem, data: PieceData, center: Vector2,
		radius: float, alpha: float = 1.0) -> void

# board/board.gd
class_name Board
extends Node2D
const WALL_EXTENSION_ABOVE: float = 400.0
@onready var danger_zone: DangerZone = $DangerZone
@onready var pieces_root: Node2D = $Pieces
func setup(config: GameConfig) -> void          # crea las 3 RectangleShape2D de Walls; danger_zone.setup(config)
func clamp_drop_x(x: float, radius: float) -> float          # clamp(x, r, W − r)
func clamp_piece_position(pos: Vector2, radius: float) -> Vector2   # x como arriba; y ≤ H − r
func set_frozen(frozen: bool) -> void           # pieces_root.process_mode DISABLED / INHERIT
func clear_pieces() -> void                     # remove_child + queue_free de cada hija
func get_pieces() -> Array[Piece]
# _draw: fondo interior, paredes (placeholder madera) y línea de peligro discontinua

# board/danger_zone.gd
class_name DangerZone
extends Area2D
func setup(config: GameConfig) -> void   # rectángulo de y = −E a y = danger_line_y, ancho W
func get_pieces_inside() -> Array[Piece]
# get_overlapping_bodies() filtrados a: es Piece, is_instance_valid y is_inside_tree().
# Los solapes van un paso de física por detrás: una pieza quitada con remove_child
# sigue apareciendo en el mismo frame, y una recién añadida tarda ~2 frames.
```

**Escenas:**

- `piece.tscn`: `Piece (RigidBody2D)`, con hijos `CollisionShape2D` **sin
  shape** y `Visual (Node2D, piece_visual.gd)`. Propiedades del cuerpo:
  - `collision_layer = 2`, `collision_mask = 3`;
  - `contact_monitor = true`, `max_contacts_reported = 16` (una pieza grande
    rodeada de pequeñas supera fácilmente 8 contactos, y se perderían
    fusiones);
  - `continuous_cd = CCD_MODE_CAST_SHAPE`;
  - `linear_damp = 0.1`, `angular_damp = 0.8`;
  - `disable_mode = DISABLE_MODE_MAKE_STATIC`;
  - `physics_material_override`: `PhysicsMaterial` con friction 0.3 y
    bounce 0.15.
- `board.tscn`: `Board (Node2D)`, con hijos `Walls (StaticBody2D,
  collision_layer = 1, collision_mask = 0)`, `DangerZone (danger_zone.tscn)`
  y `Pieces (Node2D)`.
- `danger_zone.tscn`: `Area2D` con un `CollisionShape2D`.
  `collision_layer = 0`, `collision_mask = 2`, `monitoring = true`,
  `monitorable = false`.

**Paredes** (`t = wall_thickness`, `E = WALL_EXTENSION_ABOVE`):

| Pared     | Centro                  | Tamaño        |
| --------- | ----------------------- | ------------- |
| Izquierda | `(−t/2, (H − E)/2)`     | `(t, H + E)`  |
| Derecha   | `(W + t/2, (H − E)/2)`  | `(t, H + E)`  |
| Suelo     | `(W/2, H + t/2)`        | `(W + 2t, t)` |

**Placeholder de `draw_piece`**, en este orden:

1. **Halo**, si `glow_strength > 0`: 4 círculos concéntricos hasta
   `radius × (1 + 0.45 × glow)`, con `color.lightened(0.4)` y alfa
   `0.12 × glow` cada uno.
2. **Cuerpo**: `draw_circle(color)`, o la `texture` escalada al diámetro si
   existe.
3. **Borde**: `draw_arc` con `color.darkened(0.35)`, de 2 px.
4. **Reflejo**: círculo pequeño con `color.lightened(0.5)` en
   `(−0.35r, −0.35r)`.
5. **Número de nivel** centrado (`ThemeDB.fallback_font`), para que se lea
   mientras no haya arte.

**Rotación:** el `Visual` es hijo de un `RigidBody2D` que rueda. Sin
textura, `PieceVisual._process` fija `global_rotation = 0`, de modo que el
número y el reflejo quedan siempre derechos (el círculo no cambia al rotar).
Con textura, el visual rota con el cuerpo. Las instancias usadas fuera de
una pieza (vista previa, iconos) no necesitan esto.

**Detalle crítico:** no modifiques nunca la shape del sub-recurso de la
escena, porque se comparte entre todas las instancias. Cada `Piece` crea la
suya.

### Pasos

1. Escribe los scripts y las escenas del contrato.
2. Añade `make_piece` a `data_factory.gd` y crea `stub_danger_zone.gd`.

### Tests

- `test_piece.gd` (unit, con `add_child_autofree`):
  - tras `setup` + `_ready`, el radio de la shape es igual a `data.radius`;
  - dos piezas tienen **instancias distintas** de shape;
  - `mass == (radius/16)²`;
  - `consume()` → `is_consumed()`.
- `test_board.gd` (unit):
  - tras `setup`, las tres paredes tienen el centro y tamaño de la tabla;
  - `clamp_drop_x` y `clamp_piece_position` funcionan en los bordes;
  - `clear_pieces()` deja `pieces_root.get_child_count() == 0` en el mismo
    frame;
  - `set_frozen` cambia el `process_mode`.
- `test_piece_physics.gd` (integración, con `Board` real y
  `wait_physics_frames` / `wait_until`):
  - una pieza `DROPPING` soltada sobre el tablero vacío pasa a `ACTIVE` y
    reposa en `y ≈ H − r` (±2 px) antes de 180 frames de física;
  - dos piezas que caen una sobre otra emiten `contact_detected`;
  - `DangerZone.get_pieces_inside()` incluye una pieza congelada
    (`freeze = true`, `freeze_mode = FREEZE_MODE_KINEMATIC`) en `y = 50` y
    excluye otra en `y = 400`. Espera **al menos 2 frames de
    física** tras `add_child` antes de consultar, porque los solapes se
    actualizan después del paso;
  - una pieza quitada con `board.clear_pieces()` no aparece en
    `get_pieces_inside()` en el mismo frame;
  - con el tablero congelado, una pieza no se mueve en 30 frames.

**Commit:** `feat(tablero): Piece, PieceVisual, Board y DangerZone construidos desde GameConfig`

---

## Fase 4 — Soltar piezas (primer jugable)

**Objetivo:** apuntar, soltar y ver cómo se apilan las piezas. Todavía sin
fusiones.

### Contrato

```gdscript
# systems/piece_spawner.gd
class_name PieceSpawner extends Node
signal piece_spawned(piece: Piece)
const PIECE_SCENE: PackedScene = preload("res://piece/piece.tscn")
func setup(pieces_root: Node2D) -> void
func spawn(data: PieceData, position: Vector2, initial_state: Piece.State) -> Piece  # setup → add_child → emit
func despawn(piece: Piece) -> void            # remove_child + queue_free

# systems/drop_system.gd
class_name DropSystem extends Node
signal aim_changed(x: float)
signal drop_ready_changed(is_ready: bool)
signal piece_dropped(piece: Piece)
func setup(state: GameState, generator: PieceGenerator, spawner: PieceSpawner,
		board: Board, config: GameConfig) -> void
func reset() -> void
# orden: aim = W/2 y cooldown = 0 PRIMERO; luego set_queue(next(), next());
# al final emite siempre aim_changed(get_aim_x()) y drop_ready_changed(true)
func request_aim_global(global_x: float) -> void   # convierte con board.to_local()
func request_aim_step(direction: float, delta: float) -> void   # aim += dir · aim_speed · delta
func request_drop() -> bool                  # 04 §5; false si se ignoró
func tick(delta: float) -> void              # cooldown; al llegar a 0 → drop_ready_changed(true)
func get_aim_x() -> float                    # aim sin limitar → clamp con el radio del ACTUAL (o W/2 si es null)
func is_drop_ready() -> bool

# ui/drop_controller.gd
class_name DropController extends Node
signal aim_requested(global_x: float)
signal aim_step_requested(direction: float, delta: float)
signal drop_requested
signal restart_requested
# _unhandled_input: MouseMotion → aim_requested(event.position.x)  (sin Camera2D: viewport = global)
#                   acción "drop" → drop_requested; acción "restart" → restart_requested
# _process: dir = Input.get_axis("aim_left", "aim_right"); si dir != 0 → aim_step_requested

# ui/drop_preview.gd
class_name DropPreview extends Node2D
func setup(state: GameState, drop_system: DropSystem, config: GameConfig) -> void
# dibuja el ACTUAL en (aim_x, spawn_y) con PieceVisual.draw_piece (alfa 0.4 durante el cooldown)
# y una línea guía discontinua hasta H; oculta si no está PLAYING

# game/main.gd (parcial; se completa en las fases 5–7)
class_name Main extends Node
@export var config: GameConfig = preload("res://game/game_config.tres")
const BOARD_TOP_MARGIN: float = 80.0
# Getters para los tests de integración (solo lectura; ningún componente del juego los usa).
# En esta fase:
func get_state() -> GameState
func get_board() -> Board
func get_spawner() -> PieceSpawner
func get_drop_system() -> DropSystem
func get_drop_controller() -> DropController
# Fase 5: get_merge_system() -> MergeSystem
# Fase 6: get_danger_system() -> DangerSystem
# Fase 7: get_ui() -> GameUI
# _ready: errores = GameConfigValidator.validate(config); si hay → push_error de cada uno y return
#         _compose(); _start_new_game()
```

`DropSystem.request_drop()`, paso a paso:

1. Si no está `PLAYING` o el cooldown es > 0, devuelve `false`.
2. `x = board.clamp_drop_x(aim_x, current.radius)`.
3. `spawner.spawn(current, Vector2(x, spawn_y), DROPPING)`.
4. `state.advance_queue(generator.next())`.
5. Cooldown = `drop_cooldown`; emite `drop_ready_changed(false)` y
   `piece_dropped`.
6. Devuelve `true`.

**Apuntado:** `DropSystem` guarda `_aim_x` **sin limitar** (la intención del
jugador) y limita solo al leerlo, en `get_aim_x()` y al soltar. Así, al pasar
a una pieza más pequeña se recupera la posición original. Se suscribe a
`state.current_piece_changed` para emitir `aim_changed(get_aim_x())` cuando
cambia el radio. Si el dato es `null`, no hace nada.

### Pasos

1. Escribe el spawner, el `DropSystem`, el controlador y la vista previa.
2. Crea `game/main.tscn` con el árbol de `02` §5, pero **solo con los nodos
   cuyas clases ya existen**: `World/Board`, `World/DropPreview`,
   `Systems/PieceSpawner`, `Systems/DropSystem` y `DropController`. Los demás
   se añaden en sus fases. Crea `tests/helpers/board_rig.gd`.
3. En `main.gd`:
   - `_compose()`:
     - crea `GameState` y `PieceGenerator`;
     - coloca `World` en `((get_viewport().get_visible_rect().size.x − container_width)/2, BOARD_TOP_MARGIN)`
     y lo vuelve a colocar con `get_viewport().size_changed`, porque con
     `stretch/aspect="expand"` el ancho visible cambia según la ventana;
     - llama a `board.setup`, `spawner.setup`, `drop.setup` y
       `preview.setup`;
     - conecta `DropController` → `DropSystem`.
   - `_start_new_game()`, en su versión parcial de `02` §8.5:
     `board.clear_pieces`, `generator.reset`, `state.reset`, `drop.reset`,
     `board.set_frozen(false)`, `state.start`.

### Tests

- `test_piece_spawner.gd`:
  - `spawn` añade una hija en la posición y el estado pedidos y emite
    `piece_spawned`;
  - `despawn` la quita en el mismo frame.
- `test_drop_system.gd` (unit, con `board_rig` y llamando a `tick()` directamente):
  - `request_drop` devuelve `false` en `READY` y en `GAME_OVER`;
  - en `PLAYING` crea una pieza en `(clamp, spawn_y)` con estado
    `DROPPING`, avanza la cola y emite `piece_dropped`;
  - una segunda soltada antes de `drop_cooldown` devuelve `false`; tras
    `tick(0.5)` devuelve `true`;
  - `drop_ready_changed` se emite al empezar y al terminar el cooldown;
  - apuntar a `x = −1000` → `get_aim_x() == radius_actual`;
  - si el ACTUAL pasa a ser más grande, el apuntado se vuelve a limitar y
    emite `aim_changed`; si luego vuelve a ser pequeño, se recupera la X
    original;
  - `state.reset()` (ACTUAL nulo) no provoca errores y `get_aim_x()`
    devuelve W/2;
  - `request_aim_step(1, 0.1)` desplaza 60 px;
  - tras apuntar a otra X y entrar en cooldown, `reset()` emite
    `aim_changed(W/2)` y `drop_ready_changed(true)`.

**Verificación manual:** ejecuta el juego, apunta con el ratón y con A/D, y
suelta. Las piezas se apilan, no hay fusiones y nunca atraviesan las paredes
(ni siquiera soltando junto al borde). Haz una captura con Movie Maker y
revísala.

**Commit:** `feat(drop): apuntado, soltado con cooldown y cola de piezas`

---

## Fase 5 — Fusiones y puntuación

**Objetivo:** que dos piezas iguales se fusionen, haya cascadas y se sumen
puntos.

### Contrato

```gdscript
# systems/merge_system.gd
class_name MergeSystem extends Node
signal pieces_merged(source: PieceData, result: PieceData, position: Vector2)
signal max_level_merged(source: PieceData, position: Vector2)
func setup(state: GameState, spawner: PieceSpawner, board: Board) -> void
func register_piece(piece: Piece) -> void    # piece.contact_detected.connect(handle_contact)
func handle_contact(a: Piece, b: Piece) -> void
func tick() -> void
func reset() -> void
func get_pending_count() -> int

# systems/progress_system.gd
class_name ProgressSystem extends Node
func setup(state: GameState, config: GameConfig, merge_system: MergeSystem) -> void
# _on_merge_system_pieces_merged: state.add_score(result.score_value)
# _on_merge_system_max_level_merged: state.add_score(config.victory_bonus); state.set_victory()
```

**`handle_contact(a, b)`** (ocurre durante el flush de física: **no**
crees ni elimines cuerpos aquí):

1. Ignora si no está `PLAYING`, si `a == b`, si `a.data != b.data` o si
   alguna está `CONSUMED`.
2. `a.consume(); b.consume()`.
3. Encola el par (`_pending_a.append(a); _pending_b.append(b)`, ambos
   `Array[Piece]`).

**`tick()`** (desde `_physics_process`), para cada par en orden:

1. Si ya no está `PLAYING`, vacía `_pending` y sale.
2. `pos = (a.position + b.position) / 2`; `source = a.data`.
3. `spawner.despawn(a)` y `spawner.despawn(b)`. **Primero se eliminan.**
4. Si `source.is_max_level()` → `max_level_merged.emit(source, pos)`.
5. Si no:
   - `p = board.clamp_piece_position(pos, source.next_piece.radius)`;
   - `spawner.spawn(source.next_piece, p, ACTIVE)`;
   - `pieces_merged.emit(source, source.next_piece, p)`.
6. Al terminar, vacía `_pending`.

### Pasos

1. Escribe `MergeSystem` y `ProgressSystem`.
2. Añade `Systems/MergeSystem` y `Systems/ProgressSystem` a `main.tscn`.
3. En `main.gd`:
   - añade `get_merge_system()`;
   - llama a `merge.setup` y a `progress.setup`;
   - conecta `spawner.piece_spawned` → `merge.register_piece`;
   - añade `merge.reset()` al principio de `_start_new_game()`.

### Tests

- `test_merge_system.gd` (unit, con `board_rig`, piezas creadas con su
  spawner y `handle_contact`/`tick` llamados directamente):
  - mismo `data` → ambas `CONSUMED` y `get_pending_count() == 1`;
  - distinto `data` → no cambia nada;
  - `handle_contact(a, a)` → se ignora;
  - A+B y luego B+C (los tres iguales) → 1 pendiente y C no consumida;
  - contacto con la partida no en `PLAYING` → se ignora;
  - `tick()`:
    - A y B eliminadas;
    - existe una pieza `next_piece` en el punto medio limitado, en estado
      `ACTIVE`;
    - se emite `pieces_merged`;
  - punto medio junto a una pared → la nueva pieza queda limitada a `x ≥ r`;
  - dos piezas de nivel máximo → `max_level_merged`, no se crea ninguna
    pieza;
  - si el estado deja de ser `PLAYING` a mitad de la cola, el resto no se
    resuelve;
  - `reset()` vacía la cola.
- `test_progress_system.gd`:
  - `pieces_merged` suma `result.score_value`;
  - `max_level_merged` suma `victory_bonus` y pasa a `VICTORY`.
- `test_merge_integration.gd` (`main.tscn` con la config de integración y
  `FixedSpawnStrategy(1)`; las piezas extra se crean con
  `main.get_spawner()`):
  - dos soltadas en la misma X, esperando el cooldown → antes de 180
    frames de física queda exactamente 1 pieza de nivel 2 y el score es 3;
  - cascada: una pieza de nivel 2 en el suelo y dos de nivel 1 encima →
    termina con 1 pieza de nivel 3 y score `3 + 6 = 9`.

**Verificación manual:** juega dos minutos. Las fusiones ocurren al tocarse,
la pieza nueva no "explota" a sus vecinas y las cascadas se encadenan.

**Commit:** `feat(merge): resolución de fusiones, cascadas y puntuación`

---

## Fase 6 — Peligro y Game Over

**Objetivo:** la condición de derrota, con su retardo y la exención de las
piezas en caída.

### Contrato

```gdscript
# systems/danger_system.gd
class_name DangerSystem extends Node
signal danger_changed(ratio: float)          # 0..1, solo si cambia (reset() emite siempre)
func setup(state: GameState, danger_zone: DangerZone, config: GameConfig) -> void
func tick(delta: float) -> void
func reset() -> void                         # borra los timers y emite danger_changed(0)
```

**`tick(delta)`:**

1. Si no está `PLAYING`, no hace nada.
2. `dentro` = `danger_zone.get_pieces_inside()`, filtradas a
   `state == ACTIVE`.
3. `_timers[id] += delta` para las de dentro; borra las entradas de las que
   ya no están.
4. Emite `danger_changed(max / game_over_delay)` (limitado a 1, solo si
   cambia).
5. Si el máximo ≥ `game_over_delay` → `state.set_game_over()`.

### Pasos

1. Escribe `DangerSystem`.
2. Añade `Systems/DangerSystem` a `main.tscn`.
3. En `main.gd`:
   - añade `get_danger_system()`;
   - llama a `danger.setup(state, board.danger_zone, config)`;
   - añade `danger.reset()` a `_start_new_game()`;
   - conecta `state.status_changed` → `_on_state_status_changed`, que llama a
     `board.set_frozen(_state.is_finished())`. La regla vive en `GameState`;
     `Main` no evalúa estados.

### Tests

- `test_danger_system.gd` (unit, con `stub_danger_zone.gd` y `tick()`):
  - una pieza `ACTIVE` dentro: `tick(0.5)` → sigue `PLAYING` y
    `danger_changed(0.5)`; otro `tick(0.5)` → `GAME_OVER`;
  - una pieza `DROPPING` dentro no cuenta;
  - si sale tras 0.8 s y vuelve, el contador empieza de cero;
  - fuera de `PLAYING`, `tick` no hace nada;
  - `reset()` borra los contadores.
- `test_danger_integration.gd` (`main.tscn`):
  - una pieza `ACTIVE` congelada (`FREEZE_MODE_KINEMATIC`) sobre la línea:
    sigue `PLAYING` a los 50 frames de física y está en `GAME_OVER` a los 75
    (60 de retardo + latencia del Area). Después, el tablero queda congelado
    y `request_drop` devuelve `false`;
  - soltar 1 pieza en el tablero vacío y esperar 120 frames → sigue
    `PLAYING` (exención de `DROPPING`).

**Commit:** `feat(danger): condición de derrota con retardo y exención de piezas en caída`

---

## Fase 7 — Interfaz, efectos, victoria y reinicio

**Objetivo:** el juego completo y jugable de principio a fin.

### Contrato

```gdscript
# ui/piece_icon.gd
class_name PieceIcon extends Control
func set_piece(data: PieceData) -> void       # null → vacío; dibuja con PieceVisual.draw_piece, escalado al rect
# custom_minimum_size obligatorio: 64×64 en NextPiece y 24×24 en la leyenda
# (en un contenedor, un Control sin tamaño mínimo mide 0×0 y no se ve)

# ui/effects_layer.gd
class_name EffectsLayer extends Node2D
func setup(state: GameState, merge_system: MergeSystem, danger_system: DangerSystem,
		config: GameConfig) -> void
# fusión: anillo que se expande (0.25 s) con el color del resultado
# peligro: superposición roja sobre la línea, alfa = ratio · (0.5 + 0.5·sin(t·12))
# victoria: CPUParticles2D one-shot (~120, dorado/rojo), 3 anillos y destello de pantalla; ~1.5 s

# ui/game_ui.gd + game_ui.tscn
class_name GameUI extends CanvasLayer
signal restart_requested
func setup(state: GameState, catalog: PieceCatalog) -> void
```

Estructura de `game_ui.tscn`:

```text
GameUI (CanvasLayer)
└── Root (Control, rect completo, mouse_filter = IGNORE)
    ├── LeftPanel (VBoxContainer)  Title "El Alquimista Pobre", ScoreLabel, ScoreValue
    ├── RightPanel (VBoxContainer) NextLabel "Próximo", NextPiece (PieceIcon),
    │                              Legend (VBoxContainer, se rellena en setup: icono + nombre + rareza)
    ├── GameOverView (PanelContainer, oculto)  "La transmutación ha fallado", FinalScore, RestartButton
    └── VictoryView  (PanelContainer, oculto)  "¡Magnum Opus!", "Has creado la Piedra Filosofal",
                                               FinalScore, RestartButton
```

- `VictoryView` aparece `victory_view_delay` segundos después de `VICTORY`
  (`@export var victory_view_delay: float = 1.5` en `GameUI`), para no tapar
  la animación. El retardo usa un `Timer` hijo.
- **Cualquier cambio de estado distinto de `VICTORY`/`GAME_OVER` oculta
  ambas vistas y detiene ese `Timer`.** Si no, una victoria reiniciada con
  `R` antes de 1.5 s mostraría la pantalla encima de la nueva partida.
- Los observadores de `next_piece_changed` aceptan `null` (`PieceIcon` vacío).
- **Todos los contenedores no interactivos usan `mouse_filter = IGNORE`**;
  si no, se comerían los clics de soltado.

### Pasos

1. Escribe `PieceIcon`, `EffectsLayer` y `GameUI`.
2. Añade `EffectsLayer` (bajo `World`) y `GameUI` a `main.tscn`.
3. En `main.gd`:
   - añade `get_ui()`;
   - llama a `effects.setup` y a `ui.setup`;
   - conecta `ui.restart_requested` y `controller.restart_requested` →
     `_on_restart_requested`, que solo reinicia si `_state.is_finished()`;
   - deja `_start_new_game()` completo, exactamente como en `02` §8.5.

### Tests

- `test_game_ui.gd`:
  - con un `GameState` real, `add_score` actualiza `ScoreValue`;
  - `next_piece_changed` actualiza `NextPiece`;
  - la leyenda tiene 8 entradas en orden;
  - `GAME_OVER` muestra `GameOverView`;
  - pulsar `RestartButton` (`pressed.emit()`) emite `restart_requested`;
  - con `victory_view_delay = 0.05`, `VictoryView` aparece tras `VICTORY`;
  - `VICTORY` y `reset()` + `start()` antes del retardo → `VictoryView` nunca
    aparece y ambas vistas quedan ocultas;
  - `reset()` (cola nula) no provoca errores.
- `test_session_integration.gd` (`main.tscn`):
  - **victoria**: dos piezas `catalog.get_by_level(catalog.get_max_level())`
    creadas con `main.get_spawner()`, en contacto sobre el suelo → `VICTORY`, score igual a `victory_bonus` y tablero
    congelado;
  - **reinicio** tras Game Over → 0 piezas, score 0, `PLAYING`,
    `get_pending_count() == 0`, tablero descongelado y ACTUAL/PRÓXIMO no
    nulos;
  - **reinicio con fusión pendiente**, en el mismo frame y sin esperar:
    1. en `PLAYING`, crear dos piezas iguales y llamar a
       `get_merge_system().handle_contact(a, b)` (pendiente = 1);
    2. `get_state().set_game_over()`;
    3. `main.get_ui().restart_requested.emit()`.

    Resultado esperado: pendiente = 0 y ninguna pieza aparece en los 10
    frames siguientes;
  - `main.get_drop_controller().restart_requested.emit()` durante
    `PLAYING` → se ignora (las piezas y el score siguen intactos).

**Verificación manual:** juega una partida completa hasta perder y reinicia.
Fuerza una victoria (temporalmente con `FixedSpawnStrategy(7)` en una config
de prueba, sin commitearla) para ver la animación. Revisa con capturas de
Movie Maker.

**Commit:** `feat(ui): HUD, leyenda de rareza, pantallas de fin, efectos y reinicio`

---

## Fase 8 — Legibilidad visual y pruebas de juego

**Objetivo:** que la progresión de valor se lea sin la leyenda y que las tres
estrategias de generación queden evaluadas.

### Pasos

1. Ajusta `PieceVisual` (concepto, sección "Cómo comunicar el valor"):
   - los niveles 1–3 se ven opacos y apagados;
   - el brillo empieza en el nivel 4;
   - un pulso suave del halo (`sin(t)`), solo en los niveles con
     `glow_strength ≥ 0.5`.
2. Fondo del taller (placeholder de color cálido) y paredes con aspecto de
   recipiente.
3. Pule la animación de victoria (duración, escala y color de la Piedra
   Filosofal).
4. **Prueba de las tres estrategias:** juega al menos 3 partidas con cada
   preset, cambiando `spawn_strategy` en `game_config.tres`. Anota en
   `docs/notas_playtest.md`: duración, nivel máximo alcanzado, score y
   sensación.
5. Ajusta solo valores de `GameConfig` o de `piece.tscn`, y solo si las
   pruebas lo piden. Anota el motivo.

**Commits:**
- `feat(visual): legibilidad de rareza, brillo y pulido de victoria`
- `docs(playtest): …` para las notas

---

## Fase 9 — Opcionales (solo si se piden)

- **Logro "Magnum Opus"** (primera victoria):
  - `game/achievement_store.gd` (`RefCounted`, **no autoload**), que
    persiste en `user://achievements.cfg` con `ConfigFile`;
  - `Main` lo crea y llama a `unlock(&"magnum_opus")` al pasar a `VICTORY`;
  - `GameUI` muestra un aviso de "Logro desbloqueado" la primera vez;
  - los tests usan una ruta temporal inyectada.
- **Selector de estrategia de depuración**, solo si `OS.is_debug_build()`:
  F1/F2/F3 cambian el preset con `PieceGenerator.set_strategy`, reinician y
  muestran el nombre en pantalla.
- Récord local, audio y arte definitivo.

---

## Verificación final contra los criterios de aceptación (`04` §17)

| Criterio       | Cubierto por                                                  |
| -------------- | ------------------------------------------------------------- |
| 1 Colocación   | `test_drop_system` (clamp, posición), verificación manual F4  |
| 2 Cooldown     | `test_drop_system`                                            |
| 3 Física       | `test_piece_physics`                                          |
| 4 Fusión       | `test_merge_system`, `test_merge_integration`                 |
| 5 No fusión    | `test_merge_system`                                           |
| 6 Consumo      | `test_merge_system` (A+B, B+C)                                |
| 7 Cascada      | `test_merge_integration`                                      |
| 8 Puntuación   | `test_progress_system`, `test_merge_integration`              |
| 9 Cola         | `test_game_state`, `test_drop_system`                         |
| 10 Generación  | `test_spawn_strategies`, `test_piece_generator`               |
| 11 Exención    | `test_danger_system`, `test_danger_integration`               |
| 12 Game Over   | `test_danger_integration`                                     |
| 13 Victoria    | `test_progress_system`, `test_session_integration`            |
| 14 Reinicio    | `test_session_integration`                                    |

---

## Desviaciones

*(El agente implementador anota aquí cualquier cambio respecto a esta guía,
con su motivo y la fase en que ocurrió.)*
