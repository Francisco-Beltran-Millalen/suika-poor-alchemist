# Diseño técnico

## 1. Objetivo

Arquitectura técnica de **El Alquimista Pobre** en Godot 4.7. Las reglas de
juego están en `04_gameplay_design.md` y los datos en `03_data_design.md`.
Las firmas exactas de cada componente están en el plan `05_plan_implementacion.md`.

La arquitectura separa tres responsabilidades:

```text
DATOS         definen qué existe (Resources inmutables)
SIMULACIÓN    ejecuta la partida (física, reglas, estado)
PRESENTACIÓN  muestra la partida y traduce input en intenciones
```

---

## 2. Dirección de dependencias

**Convención única en este documento: `A ──▶ B` significa "A depende de B"**
(A conoce, referencia o llama a B).

```text
PRESENTACIÓN ──▶ SIMULACIÓN ──▶ DATOS
      │                            ▲
      └────────────────────────────┘
```

Permitido:

- la simulación lee datos;
- la presentación lee datos (colores, nombres, radios) y **observa** señales
  de la simulación;
- la presentación envía **intenciones** a la simulación (`request_drop()`,
  `restart_requested`), siempre conectadas por `Main`.

Prohibido:

- que los datos conozcan la simulación o la presentación (DATOS ──▶ cualquiera);
- que la simulación conozca la presentación (`Control`, `Label`, vistas,
  animaciones de UI);
- que la presentación modifique el estado o las piezas (`state.score += …`,
  `piece.queue_free()`).

`Main` queda fuera de las capas: es el *composition root* y puede conocerlas
todas.

---

## 3. Composition root: `Main`

`game/main.gd` es el único ensamblador. Sus responsabilidades:

```text
cargar y validar la configuración
crear los objetos sin nodo (GameState, PieceGenerator)
inyectar dependencias con setup(...)
conectar señales
iniciar / reiniciar la partida
congelar o descongelar el tablero al cambiar el estado
```

No contiene reglas de fusión, puntuación, peligro ni UI. Si crece, una
responsabilidad debe irse a su sistema.

Reglas:

- Nada de `get_node("/root/...")` ni rutas `../../`.
- **Ningún autoload.**
- Los componentes reciben sus dependencias con `setup(...)` antes de usarse y
  nunca buscan a `Main`.

---

## 4. Componentes

| Componente               | Capa         | Tipo base       | Archivo                              |
| ------------------------ | ------------ | --------------- | ------------------------------------ |
| `PieceData`              | Datos        | `Resource`      | `piece/piece_data.gd`                |
| `PieceCatalog`           | Datos        | `Resource`      | `piece/piece_catalog.gd`             |
| `PieceCatalogValidator`  | Datos        | `RefCounted` (estático) | `piece/piece_catalog_validator.gd` |
| `GameConfigValidator`    | Datos        | `RefCounted` (estático) | `game/game_config_validator.gd` |
| `SpawnStrategy` (+2)     | Datos        | `Resource`      | `piece/spawn/*.gd`                   |
| `GameConfig`             | Datos        | `Resource`      | `game/game_config.gd`                |
| `GameState`              | Simulación   | `RefCounted`    | `game/game_state.gd`                 |
| `PieceGenerator`         | Simulación   | `RefCounted`    | `systems/piece_generator.gd`         |
| `Piece`                  | Simulación   | `RigidBody2D`   | `piece/piece.gd` + `.tscn`           |
| `Board`                  | Simulación   | `Node2D`        | `board/board.gd` + `.tscn`           |
| `DangerZone`             | Simulación   | `Area2D`        | `board/danger_zone.gd` + `.tscn`     |
| `PieceSpawner`           | Simulación   | `Node`          | `systems/piece_spawner.gd`           |
| `DropSystem`             | Simulación   | `Node`          | `systems/drop_system.gd`             |
| `MergeSystem`            | Simulación   | `Node`          | `systems/merge_system.gd`            |
| `DangerSystem`           | Simulación   | `Node`          | `systems/danger_system.gd`           |
| `ProgressSystem`         | Simulación   | `Node`          | `systems/progress_system.gd`         |
| `PieceVisual`            | Presentación | `Node2D`        | `piece/piece_visual.gd`              |
| `DropController`         | Presentación | `Node`          | `ui/drop_controller.gd`              |
| `DropPreview`            | Presentación | `Node2D`        | `ui/drop_preview.gd`                 |
| `EffectsLayer`           | Presentación | `Node2D`        | `ui/effects_layer.gd`                |
| `PieceIcon`              | Presentación | `Control`       | `ui/piece_icon.gd`                   |
| `BoardVisual`            | Presentación | `Node2D`        | `board/board_visual.gd`              |
| `ScreenShake`            | Presentación | `Node`          | `ui/screen_shake.gd`                 |
| `AudioDirector`          | Presentación | `Node`          | `ui/audio_director.gd`               |
| `SoundSet`               | Datos        | `Resource`      | `ui/sound_set.gd` + `.tres`          |
| `BoardSkin`              | Datos        | `Resource`      | `board/board_skin.gd` + `.tres`      |
| `DebugController`        | Presentación | `Node`          | `ui/debug_controller.gd`             |
| `GameUI`                 | Presentación | `CanvasLayer`   | `ui/game_ui.gd` + `.tscn`            |

Responsabilidad única de cada uno:

- **GameState**: almacena y notifica el estado lógico (puntuación, cola
  ACTUAL/PRÓXIMO, estado de partida). No conoce nodos ni física, y no decide
  reglas: solo valida transiciones de estado.
- **PieceGenerator**: decide el próximo tipo de pieza. Combina la
  `SpawnStrategy` con un `RandomNumberGenerator` propio, que puede tener
  semilla.
- **Piece**: cuerpo físico de una instancia. Guarda su `PieceData` y su estado
  (`DROPPING`/`ACTIVE`/`CONSUMED`) y emite `contact_detected`. No fusiona, no
  puntúa y no conoce ningún sistema.
- **Board**: construye las paredes y la zona de peligro a partir de
  `GameConfig`. Contiene el nodo `Pieces`, ofrece
  `clamp_piece_position()` y permite congelar o vaciar el tablero.
- **DangerZone**: solo detecta qué piezas solapan la zona sobre la línea.
- **PieceSpawner**: único lugar que instancia y elimina piezas. Emite
  `piece_spawned` para que se conecten las piezas creadas en ejecución.
- **DropSystem**: convierte intenciones de apuntar y soltar en piezas.
  Aplica el límite por radio y el cooldown, y avanza la cola.
- **MergeSystem**: valida contactos, marca piezas consumidas y resuelve
  fusiones. Emite `pieces_merged` / `max_level_merged`. No puntúa ni decide el
  fin de la partida.
- **DangerSystem**: aplica la regla de derrota (pieza `ACTIVE` sobre la línea
  durante `game_over_delay`).
- **ProgressSystem**: traduce fusiones en progreso: suma puntos y declara la
  victoria.
- **PieceVisual**: dibuja un material (círculo de color o textura, más el
  brillo) a partir de un `PieceData`. Lo reutilizan `Piece`, `DropPreview` y
  la UI.
- **DropController**: lee el input y emite intenciones. No conoce reglas.
- **DropPreview**: dibuja el material ACTUAL en la posición de apuntado y la
  línea guía.
- **EffectsLayer**: efectos de fusión, advertencia de peligro y animación de
  victoria.
- **BoardVisual**: dibuja una capa del recipiente (`BACK` detrás de las piezas,
  `FRONT` delante) con las texturas de `BoardSkin`, o el placeholder procedural.
  `Board` ya no dibuja nada.
- **ScreenShake**: sacude el `Stage` tras fusiones altas y en la victoria.
- **AudioDirector**: reproduce el sonido de cada evento y la música; observa
  señales y nunca decide reglas. Procesa también en pausa.
- **DebugController**: traduce F1–F4 y F12 en intenciones de depuración; solo
  actúa en builds de depuración.
- **GameUI**: puntuación, PRÓXIMO, leyenda de rareza y pantallas de Game Over
  y Victoria, con el botón de reinicio.

Nota sobre `PieceVisual` dentro de `piece.tscn`: una entidad física tiene que
verse. El visual es un nodo hijo sin reglas, que lee `PieceData` y nunca
modifica la simulación.

---

## 5. Árbol de escena

```text
main.tscn
└── Main (Node)                         game/main.gd
    ├── Background (CanvasLayer)        layer −1: TextureRect del taller
    ├── World (Node2D)                  posición = origen del interior del recipiente
    │   └── Stage (Node2D)              en (0, 0); lo sacude ScreenShake
    │       ├── Board (board.tscn)      en (0, 0) → coordenadas de tablero = locales de World
    │       │   ├── Walls (StaticBody2D)    3 CollisionShape2D creados en setup()
    │       │   ├── DangerZone (danger_zone.tscn)
    │       │   ├── BackVisual (BoardVisual)   interior, detrás de las piezas
    │       │   ├── Pieces (Node2D)     contenedor de las Piece
    │       │   └── FrontVisual (BoardVisual)  paredes y reflejos, delante
    │       ├── DropPreview (Node2D)
    │       └── EffectsLayer (Node2D)
    ├── Systems (Node)
    │   ├── PieceSpawner (Node)
    │   ├── DropSystem (Node)
    │   ├── MergeSystem (Node)
    │   ├── DangerSystem (Node)
    │   └── ProgressSystem (Node)
    ├── ScreenShake (Node)
    ├── AudioDirector (Node)
    ├── DropController (Node)
    ├── DebugController (Node)
    └── GameUI (game_ui.tscn, CanvasLayer)
```

**Todas las posiciones de la simulación están en coordenadas de tablero**:
origen en la esquina superior izquierda del interior y eje Y hacia abajo.
Como `Board`, `DropPreview` y `EffectsLayer` cuelgan de `Stage`, que está en
(0, 0) de `World`, comparten ese sistema sin conversiones. Solo el ratón requiere convertir desde
coordenadas globales (lo hace `DropSystem` con `board.to_local()`).

`Main` coloca `World` en `((ancho_visible − container_width) / 2, 80)` y lo
recoloca en `size_changed` (con `stretch/aspect="expand"` el ancho visible
varía).

---

## 6. Capas de física

| Capa | Nombre   | Quién está en ella | Máscara                          |
| ---- | -------- | ------------------ | -------------------------------- |
| 1    | `walls`  | `Walls`            | —                                |
| 2    | `pieces` | `Piece`            | `walls` + `pieces`               |
| —    | —        | `DangerZone`       | `pieces` (monitoring, no monitorable) |

Se declaran con nombre en `project.godot` (`layer_names/2d_physics/layer_1`…).

---

## 7. Comunicación (señales)

```text
DropController.aim_requested(global_x)        ─▶ DropSystem.request_aim_global
DropController.aim_step_requested(dir, delta) ─▶ DropSystem.request_aim_step
DropController.drop_requested()               ─▶ DropSystem.request_drop
DropController.restart_requested()            ─▶ Main._on_restart_requested
DropController.mute_requested()               ─▶ AudioDirector.toggle_mute
GameUI.button_pressed()                       ─▶ AudioDirector.play_ui_click
DebugController.strategy_requested(i)         ─▶ Main (cambia estrategia y reinicia)
DebugController.high_piece_requested()        ─▶ Main ─▶ GameState.debug_set_current
DebugController.overlay_toggled()             ─▶ Main ─▶ GameUI.set_debug_text
GameUI.restart_requested()                    ─▶ Main._on_restart_requested

PieceSpawner.piece_spawned(piece)             ─▶ MergeSystem.register_piece
Piece.contact_detected(piece, other)          ─▶ MergeSystem.handle_contact   (conectada en register_piece)

MergeSystem.pieces_merged(source, result, pos)─▶ ProgressSystem, EffectsLayer
MergeSystem.max_level_merged(source, pos)     ─▶ ProgressSystem, EffectsLayer
DangerSystem.danger_changed(ratio)            ─▶ EffectsLayer
DropSystem.aim_changed(x)                     ─▶ DropPreview
DropSystem.drop_ready_changed(ready)          ─▶ DropPreview

GameState.score_changed(score)                ─▶ GameUI
GameState.current_piece_changed(data)         ─▶ DropPreview, DropSystem (re-limitar el apuntado)
GameState.next_piece_changed(data)            ─▶ GameUI
GameState.status_changed(status)              ─▶ GameUI, Main (congelar)
```

Quién conecta qué:

- **Observación:** cada componente se suscribe él mismo, en su `setup()`, a
  las señales que observa. Recibe al emisor como dependencia inyectada.
- **Intenciones:** `Main` conecta las señales de la presentación con los
  métodos de los sistemas (`DropController` → `DropSystem`, `restart_requested`
  → `Main`).

`MergeSystem` conecta la señal de cada pieza dentro de `register_piece()`.
Así se resuelve el problema de las piezas creadas en ejecución: `Main` conecta
una sola vez `piece_spawned`, y el sistema se suscribe a cada pieza nueva.
`Piece` nunca conoce a `MergeSystem`.

---

## 8. Flujos

Las reglas están en `04_gameplay_design.md`; aquí solo el *quién llama a quién*.

- **Soltar:** `DropController.drop_requested` → `DropSystem.request_drop()`:
  solo en `PLAYING` y sin cooldown; limita la X por el radio del ACTUAL;
  `PieceSpawner.spawn(..., DROPPING)`; `GameState.advance_queue(...)`;
  empieza el cooldown.
- **Fusión (dos tiempos).** En el flush de contactos, `Piece.contact_detected`
  → `MergeSystem.handle_contact(a, b)` valida (`04` §8), marca ambas
  `CONSUMED` y las encola. En el `tick()` del paso siguiente, por cada par y
  en orden: si ya no es `PLAYING`, vacía la cola; elimina A y B
  (`PieceSpawner.despawn`); si el material es de nivel máximo emite
  `max_level_merged`, y si no crea la siguiente pieza en el punto medio
  limitado por `Board.clamp_piece_position` y emite `pieces_merged`.
  `ProgressSystem` puntúa y declara la victoria. Se difiere porque Godot no
  permite añadir ni eliminar cuerpos durante el flush (*"Can't change this
  state while flushing queries"*); la cola propia mantiene el orden explícito
  y se vacía al reiniciar. La pieza nueva se registra por `piece_spawned`, de
  modo que la cascada vuelve a entrar en este mismo flujo.
- **Peligro:** `DangerSystem.tick(delta)` (solo en `PLAYING`) acumula un
  contador por pieza `ACTIVE` que `DangerZone` reporta dentro; emite
  `danger_changed(max/delay)` y, al llegar a `game_over_delay`,
  `GameState.set_game_over()`. `DangerZone` cubre de `y = −400` a
  `danger_line_y` y todo el ancho.
- **Fin de partida:** `status_changed(GAME_OVER | VICTORY)` → `Main` congela el
  tablero y `GameUI` muestra la vista. Los sistemas consultan `is_playing()`.
- **Reinicio** (solo si `GameState.is_finished()`), en `Main._start_new_game()`:
  `MergeSystem.reset()`, `DangerSystem.reset()`, `Board.clear_pieces()`,
  `PieceGenerator.reset()`, `GameState.reset()`, `DropSystem.reset()`,
  descongelar y `GameState.start()`. El primer arranque usa la misma función.

---

## 9. Detalles del motor que la implementación debe respetar

1. **`contact_monitor = true` y `max_contacts_reported = 16`** en `Piece`;
   sin eso, `body_entered` nunca se emite, y con un valor bajo se pierden
   contactos de las piezas grandes.
2. **Forma única por instancia:** `Piece` crea un `CircleShape2D.new()` propio
   en `_ready()`. Si se modificara el `radius` del sub-recurso de
   `piece.tscn`, cambiaría en todas las instancias, porque se comparte.
3. **Nada de añadir o eliminar cuerpos durante el flush de contactos:** se
   difiere al `tick()` del paso siguiente (§8, Fusión).
4. **Congelar:** `Board.set_frozen(true)` pone `Pieces.process_mode =
   PROCESS_MODE_DISABLED`. `piece.tscn` usa `disable_mode =
   DISABLE_MODE_MAKE_STATIC`, de modo que las piezas quedan quietas y visibles.
5. **Paredes gruesas (`wall_thickness`) y CCD (`CCD_MODE_CAST_SHAPE`)** para
   evitar el *tunneling* de las piezas pequeñas. Las paredes laterales suben
   hasta `y = −400` para contener las pilas que sobresalen.
6. **Eliminar inmediatamente:** al quitar una pieza se hace `remove_child()`
   y luego `queue_free()`, para que los recuentos (`Pieces.get_child_count()`)
   sean correctos en el mismo frame.
7. **`setup()` antes de `add_child()`:** `PieceSpawner` llama a
   `piece.setup(data, state)` y después la añade. `Piece._ready()` aplica la
   forma, la masa y el visual.
8. **Tiempo con `tick(delta)`:** los sistemas con lógica temporal exponen un
   `tick(delta)` público, llamado desde `_physics_process`. Los tests unitarios
   lo llaman directamente, sin esperar frames reales.
9. **Despertar al eliminar:** `PieceSpawner.despawn` pone `sleeping = false` en
   todas las piezas restantes. Un cuerpo dormido no reacciona a que
   desaparezca su apoyo y quedaría flotando.

---

## 10. Recursos compartidos

Un `Resource` se comparte entre todas las instancias que lo cargan. Por eso
`PieceData`, `PieceCatalog`, `SpawnStrategy` y `GameConfig` son **de solo
lectura en ejecución**. El estado mutable vive en `Piece` (físico) y en
`GameState` (lógico).

Las estrategias de generación son la única excepción a "los Resources no
contienen lógica": son funciones puras y sin estado (`03_data_design.md` §7).

---

## 11. Estructura de archivos

El árbol completo está en `AGENTS.md` ("Estructura de Directorios") y es la
referencia única. Resumen: `game/` (composición, estado y configuración),
`board/`, `piece/` (con `data/` y `spawn/`), `systems/`, `ui/`, `assets/` y
`tests/` (`unit/`, `integration/`, `helpers/`).

---

## 12. Pruebas de desacoplamiento

| # | Pregunta                                                                         | Debe ser |
| - | -------------------------------------------------------------------------------- | -------- |
| 1 | ¿Se puede reemplazar `GameUI` sin tocar ningún sistema?                          | Sí       |
| 2 | ¿Se puede añadir un material solo con datos?                                     | Sí       |
| 3 | ¿Se pueden cambiar los parámetros físicos sin tocar la puntuación?               | Sí       |
| 4 | ¿Se puede cambiar la regla de fusión sin tocar la UI?                            | Sí       |
| 5 | ¿Se puede cambiar la regla de derrota sin tocar `Piece` ni `DangerZone`?         | Sí       |
| 6 | ¿Se puede reiniciar sin recargar la escena?                                      | Sí       |
| 7 | ¿Funcionan `MergeSystem`, `DangerSystem` y `DropSystem` en tests sin UI?         | Sí       |
| 8 | ¿Funciona una partida sin autoloads?                                             | Sí       |
| 9 | ¿Se puede cambiar la estrategia de generación sin tocar código?                  | Sí       |

---

## 13. Revisión adversaria

La arquitectura es defectuosa si aparece cualquiera de estos síntomas:

- `Main` contiene un `if` sobre reglas de juego (las consultas como
  `is_finished()` viven en `GameState`).
- `Piece` referencia un sistema, `GameState` o la UI.
- `GameUI` escribe en `GameState` o toca piezas.
- `GameState` instancia nodos o accede a la física.
- `MergeSystem` suma puntos, declara el fin de la partida o lee input.
- Hay más de un lugar que instancia `piece.tscn`.
- Se añaden o eliminan cuerpos dentro de un callback de `body_entered`.
- Aparece un autoload.
- Algún archivo supera las 400 líneas.
