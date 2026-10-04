# Diseño de datos

## 1. Objetivo

Este documento define **qué datos existen, con qué tipos y con qué valores
iniciales** en la primera implementación de **El Alquimista Pobre**.

Debe permitir crear todos los `Resource` sin volver a decidir su estructura
durante la implementación. La arquitectura está en `02_technical_design.md`;
las reglas de juego en `04_gameplay_design.md`.

Convención de coordenadas usada en todo el documento: **origen en la esquina
superior izquierda del interior del recipiente, eje Y hacia abajo** (convención
de Godot). Todas las alturas se miden desde el borde superior del interior.

---

## 2. Resources del juego

| Resource          | Archivo de clase                      | Instancias `.tres`                    |
| ----------------- | ------------------------------------- | ------------------------------------- |
| `PieceData`       | `piece/piece_data.gd`                 | `piece/data/*.tres` (8)               |
| `PieceCatalog`    | `piece/piece_catalog.gd`              | `piece/data/piece_catalog.tres`       |
| `SpawnStrategy`   | `piece/spawn/spawn_strategy.gd`       | — (abstracta)                         |
| `UniformSpawnStrategy`  | `piece/spawn/uniform_spawn_strategy.gd`  | `piece/spawn/spawn_suika_classic.tres`, `piece/spawn/spawn_uniform_1_4.tres` |
| `WeightedSpawnStrategy` | `piece/spawn/weighted_spawn_strategy.gd` | `piece/spawn/spawn_weighted.tres` |
| `GameConfig`      | `game/game_config.gd`                 | `game/game_config.tres`               |

Todos son **inmutables durante la partida**. Nadie escribe en ellos en tiempo
de ejecución.

---

## 3. PieceData

Describe un **tipo** de material, no una pieza concreta del recipiente. Diez
piezas de Cobre comparten el mismo `copper.tres`.

### 3.1. Campos

| Grupo (Inspector) | Campo           | Tipo          | Regla                                                       |
| ----------------- | --------------- | ------------- | ----------------------------------------------------------- |
| Identity          | `id`            | `StringName`  | Único, no vacío, `snake_case`                               |
| Identity          | `level`         | `int`         | Único, ≥ 1                                                  |
| Identity          | `display_name`  | `String`      | Nombre visible ("Cobre")                                    |
| Identity          | `rarity_label`  | `String`      | Etiqueta de rareza para la leyenda ("Poco común")           |
| Physics           | `radius`        | `float`       | > 0; estrictamente creciente con `level`                    |
| Progression       | `next_piece`    | `PieceData`   | `level + 1`, o `null` solo en el nivel máximo               |
| Scoring           | `score_value`   | `int`         | ≥ 0; puntos otorgados al **crear** esta pieza por fusión    |
| Presentation      | `color`         | `Color`       | Color base del placeholder y del tinte                      |
| Presentation      | `texture`       | `Texture2D`   | Opcional, **cuadrada** (la valida el catálogo). `null` → círculo con `color` |
| Presentation      | `glow_strength` | `float`       | 0.0–1.0. Intensidad del brillo (comunica rareza)            |
| Presentation      | `rarity_color`  | `Color`       | Color de la etiqueta de rareza en la leyenda (alfa > 0)     |

**Decisiones:**

- **No existe un campo `collision_shape`.** El radio es la única fuente de
  verdad del tamaño. `Piece` construye su `CircleShape2D` y escala su visual a
  partir de `radius`. Así se evita que el tamaño visual y el físico se
  desincronicen.
- Los campos de `Presentation` son datos; los consume la capa visual. La
  simulación nunca los lee.
- No hay `mass`, `friction`, `bounce` ni `gravity_scale` (ver §8).

### 3.2. Métodos permitidos

`PieceData` no contiene lógica de juego. Solo se permite:

```gdscript
func is_max_level() -> bool:
	return next_piece == null
```

---

## 4. La cadena de materiales

Ocho niveles, tomados de la referencia visual
(`docs/El Alquimista Pobre_ De Basura a Leyenda.png`):

| Nivel | `id`                | `display_name`      | `rarity_label` | `radius` | `score_value` | `color`   | `glow_strength` |
| ----- | ------------------- | ------------------- | -------------- | -------- | ------------- | --------- | --------------- |
| 1     | `trash`             | Basura              | Común          | 16       | 1             | `#6b6358` | 0.0             |
| 2     | `scrap_metal`       | Metal común         | Común          | 22       | 3             | `#8a6f5a` | 0.0             |
| 3     | `copper`            | Cobre               | Poco común     | 29       | 6             | `#c8642d` | 0.0             |
| 4     | `silver`            | Plata               | Raro           | 37       | 10            | `#c9ced6` | 0.15            |
| 5     | `gold`              | Oro                 | Muy raro       | 46       | 15            | `#f2b630` | 0.3             |
| 6     | `enchanted_gold`    | Oro encantado       | Épico          | 56       | 21            | `#ffd36b` | 0.5             |
| 7     | `celestial_matter`  | Material celestial  | Épico+         | 68       | 28            | `#7b6cff` | 0.75            |
| 8     | `philosopher_stone` | Piedra Filosofal    | Legendario     | 82       | 36            | `#e8323c` | 1.0             |

`rarity_color` (de la imagen de referencia): `#8c7970`, `#816b5f`, `#6c9c48`,
`#4594f7`, `#c652e1`, `#cc3efa`, `#fdb227`, `#fdd858` (niveles 1 a 8).

Encadenamiento: `trash → scrap_metal → … → philosopher_stone → null`.

El brillo empieza en Plata (Raro), como pide el concepto: los materiales
comunes son opacos y el brillo crece con la rareza.

**Comprobación de tamaños** (recipiente de 440 px de ancho, §6):

- dos Piedras Filosofales caben lado a lado (2 × 164 = 328 < 440);
- la pieza más grande que puede aparecer en el spawn (Oro, nivel 5) mide
  92 px de diámetro.

### 4.1. Puntuación

`score_value` sigue la fórmula de números triangulares
`score(level) = level × (level + 1) / 2`. **La fórmula solo sirve para elegir
los valores al crear los recursos.** El código nunca la calcula; siempre lee
`score_value`.

El `score_value` del nivel 1 (1 punto) **nunca se otorga**, porque la Basura no
se crea por fusión. Se conserva para mantener la tabla uniforme y por si una
regla futura lo usa.

---

## 5. PieceCatalog

Sin un catálogo no existe ningún lugar que conozca *todas* las piezas. Lo
necesitan la validación, las estrategias de generación y la leyenda de rareza.

| Campo    | Tipo                | Regla                                    |
| -------- | ------------------- | ---------------------------------------- |
| `pieces` | `Array[PieceData]`  | Ordenado por `level`, empezando en 1     |

Métodos permitidos (consultas de solo lectura, sin estado):

```gdscript
func get_by_level(level: int) -> PieceData   # null si no existe
func get_max_level() -> int
func size() -> int
```

`next_piece` sigue siendo la fuente de verdad de la progresión. El orden del
array es redundante a propósito, y la validación (§9) comprueba que ambos
coinciden.

---

## 6. GameConfig

Configuración global de la partida.

| Grupo  | Campo               | Tipo            | Valor inicial                        | Unidad / significado                                           |
| ------ | ------------------- | --------------- | ------------------------------------ | -------------------------------------------------------------- |
| Board  | `container_width`   | `float`         | 440                                  | px, ancho interior                                             |
| Board  | `container_height`  | `float`         | 600                                  | px, alto interior                                              |
| Board  | `wall_thickness`    | `float`         | 32                                   | px; las paredes gruesas evitan que las piezas las atraviesen   |
| Board  | `danger_line_y`     | `float`         | 100                                  | px desde el borde superior del interior                        |
| Spawn  | `spawn_y`           | `float`         | 40                                   | px desde el borde superior; altura donde se suelta la pieza    |
| Spawn  | `drop_cooldown`     | `float`         | 0.5                                  | s entre una soltada y la siguiente                             |
| Spawn  | `aim_speed`         | `float`         | 600                                  | px/s al apuntar con teclado                                    |
| Spawn  | `spawn_strategy`    | `SpawnStrategy` | `spawn_suika_classic.tres`           | Estrategia de generación (intercambiable)                      |
| Spawn  | `rng_seed`          | `int`           | 0                                    | 0 = aleatorio; ≠ 0 = semilla fija (tests y depuración)         |
| Rules  | `game_over_delay`   | `float`         | 1.0                                  | s que una pieza asentada debe seguir sobre la línea para perder |
| Rules  | `victory_bonus`     | `int`           | 100                                  | Puntos por fusionar dos piezas de nivel máximo                 |
| Pieces | `piece_catalog`     | `PieceCatalog`  | `piece_catalog.tres`                 | Catálogo de piezas                                             |

**Restricciones entre valores** (las comprueba la validación):

```text
0 < spawn_y < danger_line_y < container_height
spawn_y + radio_máx_generable < danger_line_y      # 40 + 46 = 86 < 100
2 × radio_máx_catálogo ≤ container_width          # 164 ≤ 440
```

**Encaje en pantalla** (viewport de 1280×720): la composición coloca el
interior del recipiente en `(420, 80)`. Así el suelo queda en y = 680 y el
grosor de la pared termina en 712. Los laterales quedan libres para la UI.

**Lo que se eliminó respecto a la versión anterior:**

- `initial_state`: era estado dentro de la configuración, y además obligaba a
  que un recurso de datos referenciara el enum de `GameState` (Simulación), lo
  que viola la dirección de dependencias. La partida siempre arranca en
  `READY` y `Main` llama a `start()`.
- `spawn_margin`: un margen fijo no sirve para piezas de tamaños distintos. El
  límite de colocación se deriva del radio de la pieza actual (ver
  `04_gameplay_design.md` §5).
- `danger_height` "desde el fondo": era inconsistente con `spawn_height`
  "desde arriba". Ahora ambos valores se miden desde arriba.

---

## 7. Estrategias de generación (plug and play)

La regla de generación se elige **cambiando un recurso en el Inspector**,
sin modificar código. Las estrategias son `Resource` intercambiables.

### 7.1. Contrato

```gdscript
class_name SpawnStrategy
extends Resource

## Devuelve el tipo de pieza a generar. Debe ser una función pura:
## no guarda estado y toda la aleatoriedad sale de `rng`.
func pick(catalog: PieceCatalog, rng: RandomNumberGenerator) -> PieceData

## Devuelve los errores de configuración (vacío si es válida).
func validate(catalog: PieceCatalog) -> PackedStringArray

## Nivel más alto que puede generar (para la validación de spawn_y).
func get_max_spawn_level(catalog: PieceCatalog) -> int
```

**Excepción explícita a "los Resources no contienen lógica":** las
estrategias son *políticas puras sin estado*. No conocen el árbol, la física,
el estado de la partida ni la UI. El estado (el RNG) vive en `PieceGenerator`,
que pertenece a la simulación. Una estrategia que necesitara estado propio
(por ejemplo, una "bolsa" sin repeticiones) **no** puede implementarse como
`SpawnStrategy`; tendría que vivir en la simulación.

### 7.2. Implementaciones y presets

| Preset `.tres`              | Clase                   | Parámetros                        | Uso                                 |
| --------------------------- | ----------------------- | --------------------------------- | ----------------------------------- |
| `spawn_suika_classic.tres`  | `UniformSpawnStrategy`  | `max_level = 5`                   | **Por defecto.** Regla original de Suika |
| `spawn_uniform_1_4.tres`    | `UniformSpawnStrategy`  | `max_level = 4`                   | Variante más fácil                  |
| `spawn_weighted.tres`       | `WeightedSpawnStrategy` | `weights = [40, 25, 18, 11, 6]`   | Más basura que oro                  |

- `UniformSpawnStrategy`: elige un nivel entero uniforme en `[1, max_level]`.
- `WeightedSpawnStrategy`: `weights[i]` es el peso del nivel `i + 1`. Un array
  más corto que el catálogo equivale a pesos 0 en los niveles restantes. Los
  pesos son relativos, no tienen que sumar 100.

Validación de estrategias: `max_level` en `[1, catalog.size() - 1]` (nunca se
genera el nivel máximo); pesos ≥ 0 y al menos uno > 0; ningún peso > 0 en el
nivel máximo.

---

## 8. Física de las piezas

La primera versión usa **física común** para todos los materiales. Esos
parámetros viven en la escena `piece.tscn`, no en `PieceData`:

| Parámetro                | Valor inicial                                   |
| ------------------------ | ----------------------------------------------- |
| `PhysicsMaterial.friction` | 0.3                                           |
| `PhysicsMaterial.bounce`   | 0.15                                          |
| `linear_damp`            | 0.1                                             |
| `angular_damp`           | 0.8                                             |
| `continuous_cd`          | `CCD_MODE_CAST_SHAPE`                           |
| `contact_monitor`        | `true`                                          |
| `max_contacts_reported`  | 16                                              |
| Gravedad                 | la del proyecto (980 px/s²)                     |

**La masa no es un dato:** se deriva del radio con
`mass = (radius / 16.0)²` (constante en `piece.gd`). Con masa 1 para todas,
la Basura empujaría a la Piedra Filosofal como si pesaran lo mismo.

Si las pruebas de balance demuestran que algún material necesita física
propia, se añadirá el campo a `PieceData` en ese momento, no antes.

---

## 9. Validación

`PieceCatalogValidator` (`piece/piece_catalog_validator.gd`, clase con métodos
estáticos) devuelve un `PackedStringArray` con mensajes legibles. Si está
vacío, los datos son válidos. Lo ejecutan los tests y `Main` al arrancar; con
errores, `Main` hace `push_error` de cada uno y no inicia la partida.

Detecta como mínimo:

- catálogo vacío o con entradas `null`;
- `id` vacío o duplicado;
- `level` duplicado, o `pieces[i].level != i + 1`;
- `radius ≤ 0`, o radio no estrictamente creciente;
- `score_value < 0`;
- `glow_strength` fuera de `[0, 1]`;
- `next_piece == null` antes del último nivel;
- `next_piece != null` en el último nivel;
- `next_piece.level != level + 1` (cubre autorreferencia, saltos y ciclos);
- `next_piece` que no pertenece al catálogo.

`GameConfig` añade la validación de las restricciones de §6 y la de la
estrategia (§7.2).

> Nota: Godot carga mal los `.tres` con referencias cíclicas. La regla
> `next_piece.level == level + 1` impide los ciclos por construcción.

---

## 10. Estado frente a configuración

```text
PieceData     configuración de un tipo de material
PieceCatalog  configuración: el conjunto de materiales
SpawnStrategy configuración: la política de generación
GameConfig    configuración global

Piece         estado físico de una instancia (posición, velocidad, estado)
GameState     estado lógico de una partida (puntuación, cola, estado)
```

`score_value = 15` es configuración; `score = 327` es estado. `radius` es
configuración; `position`, `linear_velocity` y `rotation` son estado de una
instancia.

---

## 11. Revisión adversaria

El diseño de datos es defectuoso si aparece cualquiera de estos síntomas:

1. **`PieceData` con lógica** (`merge()`, `spawn()`, `add_score()`): los datos
   pasan a ser simulación.
2. **`GameConfig` con estado** (`score`, `current_piece`, `status`): el estado
   se arrastra entre partidas.
3. **Cadena duplicada**: `if level == 1: …` en `MergeSystem`. La fuente de
   verdad es `next_piece`.
4. **Puntuación duplicada**: tablas de puntos fuera de `score_value`.
5. **Tamaño duplicado**: un `CollisionShape2D` con radio fijo en la escena, o
   un sprite con escala propia, además de `radius`.
6. **Configuración duplicada**: `Board.container_width` o
   `DropSystem.container_width` con valores propios. Todo sale de `GameConfig`.
7. **Recursos mutados en ejecución**: `piece.data.score_value = …`.
8. **Estrategias con estado**: una `SpawnStrategy` que guarda variables entre
   llamadas a `pick()`.
9. **Parámetros "por si acaso"**: campos sin una necesidad de diseño concreta.

---

## 12. Pruebas de diseño

| # | Pregunta                                                                       | Debe ser |
| - | ------------------------------------------------------------------------------ | -------- |
| 1 | ¿Crear un material nuevo solo requiere un `PieceData` y añadirlo al catálogo?  | Sí       |
| 2 | ¿Cambiar la progresión solo requiere modificar `next_piece`?                   | Sí       |
| 3 | ¿Cambiar la puntuación solo requiere modificar `score_value`?                  | Sí       |
| 4 | ¿Cambiar la regla de generación solo requiere cambiar `spawn_strategy`?        | Sí       |
| 5 | ¿Una nueva partida reutiliza los recursos sin arrastrar estado?                | Sí       |
| 6 | ¿Diez piezas que comparten un `PieceData` mantienen estados físicos independientes? | Sí  |
| 7 | ¿Un recurso mal configurado se detecta antes de jugar?                         | Sí       |
| 8 | ¿Cambiar el tamaño del recipiente solo requiere modificar `GameConfig`?        | Sí       |
