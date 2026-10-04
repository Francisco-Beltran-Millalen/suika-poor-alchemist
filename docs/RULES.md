# REGLAS DEL PROYECTO

> Archivo único de convenciones. Léelo completo antes de escribir código.
> Las decisiones arquitectónicas de fondo se encuentran en `docs/02_technical_design.md`.
> Este documento cubre el **cómo se escribe y cómo se organiza**.

Godot **4.7** · GDScript · **tipado estático obligatorio** en variables, parámetros y tipos de retorno.

---

## 1. Nomenclatura

### 1.1 Tabla de estilos

| Elemento                       | Estilo                                  | Ejemplo                          |
| ------------------------------ | --------------------------------------- | -------------------------------- |
| Variable local / miembro       | `snake_case`                            | `drop_position`, `current_piece` |
| Variable privada               | `_snake_case`                           | `_is_dropping`, `_accumulated_time` |
| Constante                      | `SCREAMING_SNAKE_CASE`                  | `MAX_PIECES`, `DEFAULT_GRAVITY`  |
| Enum (nombre)                  | `PascalCase`                            | `GameState`, `DropState`         |
| Enum (valor)                   | `SCREAMING_SNAKE_CASE`                  | `GameState.PLAYING`              |
| Clase (`class_name`)           | `PascalCase`                            | `DropSystem`, `PieceData`        |
| Nodo en escena                 | `PascalCase`                            | `DangerZone`, `PieceContainer`   |
| Función / método               | `snake_case`                            | `spawn_piece()`, `merge()`       |
| Función privada                | `_snake_case`                           | `_resolve_collision()`           |
| Señal                          | `snake_case` (evento pasado)            | `piece_merged`, `game_over`      |
| Callback de señal              | `_on_nodo_senal()`                      | `_on_danger_zone_body_entered()` |
| Archivo `.gd`                  | `snake_case` (coincide con `class_name`)| `drop_system.gd`, `piece_data.gd`|
| Archivo `.tscn`                | `snake_case`                            | `main.tscn`, `board.tscn`        |
| Archivo `.tres`                | `snake_case`                            | `game_config.tres`, `copper.tres`|
| Imagen / sprite                | `snake_case`                            | `cauldron_rim.png`               |
| Audio                          | `sfx_` / `bgm_` + `snake_case`          | `sfx_merge.wav`, `bgm_lab.ogg`   |
| Shader                         | `snake_case`                            | `glow_effect.gdshader`           |
| Archivo de test                | `test_` + `snake_case`                  | `test_merge_system.gd`           |

### 1.2 Reglas rápidas (correcto vs incorrecto)

| Concepto              | ✅ Correcto                          | ❌ Incorrecto                                |
| --------------------- | ------------------------------------ | -------------------------------------------- |
| Variable local        | `var drop_speed: float`              | `var DropSpeed`                              |
| Constante             | `const MAX_LEVEL: int = 8`           | `const maxLevel = 8`                         |
| Clase                 | `class_name Piece`                   | `class_name piece`                           |
| Estado con enum       | `enum State { IDLE, DROPPING }`      | `var is_idle: bool; var is_dropping: bool`   |
| Señal                 | `signal score_added(amount: int)`    | `signal OnScoreAdded(s)`                     |
| Privado               | `func _spawn() -> void:`             | `func spawnInterno():`                       |
| Función tipada        | `func can_drop() -> bool:`           | `func can_drop():`                           |
| Inferencia (visible)  | `var dir := Vector2.DOWN`            | `var dir = Vector2.DOWN` (sin tipo)          |

---

## 2. Tipado

```gdscript
var speed: float = 200.0          # siempre tipado
var dir := Vector2.DOWN           # inferencia := solo si el tipo es obvio en la misma línea
func merge(a: Piece, b: Piece) -> void:  # parámetros y retorno siempre tipados
@onready var _container: Node2D = $Container
```

- `:=` se usa cuando el tipo se lee de forma inmediata y evidente en la misma línea. Si no, tipo explícito.
- Arrays y diccionarios se tipan siempre que sea posible: `var pieces: Array[Piece] = []`.
- Nunca `var x` sin tipo ni valor.

---

## 3. Estructura del proyecto

Se sigue la recomendación oficial de Godot: **agrupar por dominio/contexto, no por tipo de archivo**.
Cada componente es dueño de su `.tscn`, `.gd` y subrecursos juntos.
La carpeta `docs/` se excluye de la importación con `.gdignore`.

```text
res://
├── game/                            # Composition root, estado de sesión y configuración
│   ├── main.tscn / main.gd
│   ├── game_state.gd
│   ├── game_config.gd / game_config_validator.gd
│   └── game_config.tres
├── board/                           # Recipiente físico y zona de peligro
│   ├── board.tscn / board.gd
│   └── danger_zone.tscn / danger_zone.gd
├── piece/                           # Pieza física, visual y recursos descriptores
│   ├── piece.tscn / piece.gd / piece_visual.gd
│   ├── piece_data.gd / piece_catalog.gd / piece_catalog_validator.gd
│   ├── data/                        # 8 materiales (.tres) + piece_catalog.tres
│   └── spawn/                       # Estrategias de generación + presets (.tres)
├── systems/                         # Sistemas de simulación independientes
│   ├── piece_generator.gd / piece_spawner.gd
│   ├── drop_system.gd / merge_system.gd
│   └── danger_system.gd / progress_system.gd
├── ui/                              # Presentación, input y efectos
│   ├── drop_controller.gd / drop_preview.gd / effects_layer.gd / piece_icon.gd
│   ├── debug_controller.gd
│   └── game_ui.tscn / game_ui.gd
├── tools/                           # Scripts de línea de comandos (balance_sim.gd)
├── assets/                          # Sprites, shaders, audio, fuentes
├── tests/                           # Tests automatizados con GUT
│   ├── unit/
│   ├── integration/
│   └── helpers/                     # Datos de test y stubs (sin class_name)
├── addons/                          # Dependencias de terceros (addons/gut/)
├── docs/                            # Documentación y GDDs (.gdignore)
└── project.godot
```

---

## 4. Scripts — orden interno (obligatorio)

Basado en la [guía de estilo oficial de Godot 4](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html#code-order):

```text
01. @tool, @icon, @static_unload
02. class_name
03. extends
04. ## doc comment

05. signals
06. enums
07. constants
08. static variables
09. @export variables
10. variables regulares
11. @onready variables

12. _static_init()
13. resto de métodos estáticos
14. virtuales built-in sobreescritos:
     1. _init()
     2. _enter_tree()
     3. _ready()
     4. _process()
     5. _physics_process()
     6. resto de virtuales
15. métodos custom sobreescritos
16. resto de métodos: públicos → privados (_) → callbacks de señales (_on_)
17. inner classes
```

**Claves:** `@onready` va después de TODAS las variables regulares. Las inner classes siempre al final del archivo. Este orden es obligatorio.

---

## 5. Arquitectura y Reglas clave

- **Dirección de dependencias:**
  ```text
  PRESENTACIÓN ──▶ SIMULACIÓN ──▶ DATOS      (A ──▶ B = "A depende de B")
  ```
  - Los datos (`PieceData`, `GameConfig`) no conocen la simulación.
  - La simulación ejecuta reglas físicas y de juego, pero desconoce la presentación.
  - La presentación (`GameUI`) reacciona a eventos y estado; nunca dicta reglas del juego.
- **Composition Root:** `Main` (`game/main.tscn`) ensambla componentes y conecta señales. Los componentes internos no usan rutas duras globales como `get_node("/root/Main/...")`.
- **Autoloads mínimos:** No usar autoloads como contenedores de lógica local o atajos rápidos. El estado de la partida vive en la composición.
- **Señales:** Preferir señales a llamadas descendentes o cruzadas no acopladas.
- **Límite duro:** Ningún archivo de código ni de documentación permanente debe superar las **400 líneas**. Los planes de implementación temporales están exentos.
- **Doc comments:** Comentarios de API con `##`, comentarios internos explicativos con `#` enfocados en el *por qué*.

---

## 6. Git

Formato de commit: `type(ámbito): qué cambia, en español`

- `feat:` — funcionalidad nueva
- `fix:` — corrección de bug
- `refactor:` — reestructuración sin cambio funcional
- `test:` — tests
- `docs:` — documentación
- `assets:` — assets (sprites, audio, etc.)
