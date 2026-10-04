# Plan de la iteración 2 (guía paso a paso)

Guía temporal para el agente implementador. **No es diseño canónico**: cuando una
fase cambia una regla, el cambio se escribe también en el documento canónico que
se indica en esa fase. Si esta guía y un documento canónico se contradicen, manda
el canónico y la discrepancia se anota en "Desviaciones", al final.

La iteración 1 (`05_plan_implementacion.md`) dejó el juego jugable de principio a
fin con placeholders: 117 tests en verde, arquitectura limpia y sin deuda
importante. Esta iteración lo convierte en un juego que se siente terminado:

1. corrige el único bug de física encontrado en la revisión;
2. añade herramientas para probar y equilibrar;
3. prepara la integración del arte con **placeholders** (el usuario crea los
   assets definitivos por separado; ver el **Anexo A**);
4. añade *game feel*, audio y una sesión completa (título, pausa, récord);
5. cierra el balance con pruebas de juego reales.

**Estrategia de assets.** La fase 2 genera, con un script, un placeholder de
**cada** asset del Anexo A con su nombre, ruta, tamaño y formato definitivos.
Las fases 3–8 conectan el juego a esos archivos (en los `.tres` y las escenas).
Así, cuando llegue un asset definitivo, integrarlo es **sustituir el archivo
con el mismo nombre y tamaño y reimportar**: sin tocar código, escenas ni
`.tres`. Un test comprueba que cada archivo cumple el Anexo A, de modo que un
asset con un tamaño equivocado se detecta al momento.

Además, el código sigue aceptando `null` en cada textura, sonido o fuente
(*fallback*: el dibujo procedural actual o silencio), para que borrar un
archivo nunca rompa el juego.

---

## Paso previo — Reglas para el agente

1. Lee en este orden: `RULES.md`, `AGENTS.md`, `04_gameplay_design.md`,
   `03_data_design.md`, `02_technical_design.md`, la sección "Desviaciones" de
   `05_plan_implementacion.md` y esta guía completa.
2. **Una fase cada vez.** No empieces la siguiente con tests en rojo.
3. Las firmas marcadas como **Contrato** son obligatorias. Puedes añadir
   métodos privados (`_x`); cualquier otra API pública nueva o cambiada se anota
   en "Desviaciones" en el mismo commit.
4. Si algo es imposible en el motor o contradice el diseño, **detente**, elige
   la alternativa más simple que respete la arquitectura y anótala.
5. Tipado estático en todo, orden interno según `RULES.md` §4, doc comments `##`
   en la API pública.
6. **Límite de 400 líneas** en código y documentación canónica.
   `02_technical_design.md` ya está en **399 líneas**: no le añadas nada sin
   compactar antes. Todo el diseño nuevo de presentación (arte, audio, efectos,
   pantallas) va en un documento canónico nuevo, `docs/07_diseno_presentacion.md`,
   que se crea en la fase 2 y se amplía en las siguientes.
7. La regla de dependencias no cambia: **Presentación → Simulación → Datos**.
   Ningún sistema de simulación conoce texturas, sonidos ni nodos de UI.
8. Al cerrar cada fase:
   1. `godot --headless --path . --import` (si hay `class_name`, recursos o
      assets nuevos);
   2. suite completa de GUT en verde;
   3. una captura con Movie Maker si la fase cambia algo visible, revisada
      antes de hacer commit;
   4. commit con el mensaje indicado (español, con ámbito).

### Comandos

```bash
godot --headless --path . --import
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
godot --path . --scene res://game/main.tscn
godot --path . --scene res://game/main.tscn --write-movie /tmp/mov/shot.png --fixed-fps 60 --quit-after 600
```

Para capturas con partida en curso, una escena temporal fuera del repo (o
borrada antes del commit) que instancie `main.tscn` y añada un nodo hijo que
llame a `get_drop_system().request_aim_step(...)` y `request_drop()` cada
~0,6 s sirve de bot. **No la subas.**

### Convenciones que siguen vigentes

Las de `05` §"Convenciones transversales" (suscripción en `setup()`, `tick(delta)`,
observadores que aceptan `null`, helpers sin `class_name`, arrays tipados,
`wait_until` dentro de `assert_true`, emisiones incondicionales en `reset()`).
Además:

- **Assets opcionales:** toda propiedad `Texture2D`, `AudioStream` o `Font` nueva
  admite `null`, y con `null` el juego se ve o suena como antes de la fase. Cada
  una tiene un test que lo comprueba. Aun así, los `.tres` y escenas apuntan a
  los placeholders de la fase 2, no a `null`.
- **Nunca se sobrescribe un asset del usuario:** el generador de placeholders
  solo crea los archivos que faltan, salvo con `--force`. Ningún agente borra
  ni regenera un archivo de `assets/` que no haya creado en esta sesión.
- **Rutas de assets:** `assets/<tipo>/<grupo>/<nombre>.<ext>`, en `snake_case`
  (`RULES.md` §1.1). Los nombres exactos están en el Anexo A.
- **Persistencia:** nunca en autoloads. Clases `RefCounted` creadas por `Main`
  con la ruta inyectada; los tests usan una ruta temporal en `user://` y la
  borran en `after_each`.

---

## Fase 0 — Corrección: piezas dormidas que quedan flotando

**Problema (reproducido en la revisión):** cuando una pieza lleva un rato quieta,
Godot la duerme (`sleeping = true`). Si después se elimina la pieza que la
sostiene (porque esa se fusiona), la dormida **no se despierta** y queda flotando
en el aire. Prueba realizada: una Basura dormida sobre un Oro se quedó en
`y = 504` tras quitar el Oro, cuando debía caer a `y = 584`. En partida pasa al
fusionar una pieza que tiene otras ya asentadas encima.

### Contrato

```gdscript
# systems/piece_spawner.gd
## Quita la pieza de inmediato (`remove_child` + `queue_free`) y despierta las
## piezas restantes: un cuerpo dormido no reacciona a que desaparezca su apoyo.
func despawn(piece: Piece) -> void
```

### Pasos

1. En `PieceSpawner.despawn`, tras `remove_child`, recorre
   `_pieces_root.get_children()` y pon `sleeping = false` en cada `Piece`.
   Despertar a todas (y no solo a las que tocaban la eliminada) es deliberado:
   una pila dormida de varias piezas solo se despierta en cadena si se mueve la
   de abajo, y `get_colliding_bodies()` solo da las que tocan directamente.
   Con ~50 piezas el coste es despreciable.
2. **No** uses `can_sleep = false` en `piece.tscn`: funciona, pero deja toda la
   simulación activa siempre y añade temblor en pilas altas.
3. **Haz sitio en `02_technical_design.md`** para toda la iteración: las fases
   siguientes añaden componentes (`DebugController`, `BoardVisual`, `Stage`,
   `ScreenShake`, `AudioDirector`, `ScoreStore`) que deben figurar en §4
   (componentes), §5 (árbol de escena) y §11 (archivos). Compacta §8 (los flujos
   repiten lo que ya dicen `04` y el código) hasta dejar el archivo en **≤ 360
   líneas**, sin perder reglas. Después añade a §9 el punto "despertar al
   eliminar". Cada fase que cree un componente lo añade a §4, §5 y §11 en su
   mismo commit; el detalle de presentación va en `07`.
4. Actualiza el estado del `README.md`: "jugable de principio a fin; iteración 2
   en curso (`docs/06_plan_iteracion_2.md`)".

### Tests (`tests/integration/test_piece_physics.gd`)

- `test_sleeping_piece_falls_when_support_is_despawned`: con un `PieceSpawner`
  real, crea un apoyo de nivel 5 en el suelo y una pieza de nivel 1 encima;
  espera ~240 frames de física y comprueba la precondición `top.sleeping`;
  `spawner.despawn(apoyo)`; tras 120 frames la de arriba reposa en
  `container_height − radius` (±3 px).
- Unitario en `tests/unit/test_piece_spawner.gd`: crea tres piezas, fuerza
  `sleeping = true` en las dos que quedarán (una pieza recién creada nunca está
  dormida, y sin forzarlo el test pasaría aunque `despawn` no despertara nada),
  `despawn` de la tercera, y comprueba que ninguna restante tiene
  `sleeping == true`.

**Hecho cuando:** los dos tests pasan y el resto de la suite sigue en verde.

**Commit:** `fix(física): despertar las piezas al eliminar una para que no floten`

---

## Fase 1 — Herramientas de depuración y balance

**Objetivo:** que probar y equilibrar sea rápido. La fase 8 de la iteración 1
quedó con las pruebas de juego sin hacer porque requieren partidas humanas; aquí
se dan las herramientas para hacerlas y una medición automática complementaria.

### Contrato

```gdscript
# ui/debug_controller.gd  (Presentación; solo activo si OS.is_debug_build())
class_name DebugController
extends Node
signal strategy_requested(index: int)   # F1, F2, F3 → índices 0, 1, 2
signal high_piece_requested             # F4
signal overlay_toggled                  # F12

# game/main.gd (añadidos)
## Presets que F1–F3 activan. Solo se usan en builds de depuración.
@export var debug_strategies: Array[SpawnStrategy] = []

# game/game_state.gd (añadido)
## Sustituye el ACTUAL sin avanzar la cola. Solo para depuración.
func debug_set_current(data: PieceData) -> void

# game/main.gd (añadido; getter de solo lectura para los tests, como los demás)
func get_debug_controller() -> DebugController

# ui/game_ui.gd (añadido)
## Texto de depuración en una esquina; cadena vacía lo oculta.
func set_debug_text(text: String) -> void
```

### Pasos

1. Acciones nuevas en el InputMap: `debug_strategy_1` (F1), `debug_strategy_2`
   (F2), `debug_strategy_3` (F3), `debug_high_piece` (F4),
   `debug_overlay` (F12).
2. `DebugController` (nodo en `main.tscn`): en `_ready`, si
   `not OS.is_debug_build()`, `set_process_unhandled_input(false)` y nada más.
   Traduce las acciones a sus señales; no conoce reglas.
3. `Main`:
   - en `main.tscn`, `debug_strategies` = los tres presets de
     `piece/spawn/` (clásico, uniforme 1–4, ponderado);
   - `strategy_requested(i)` → `_generator.set_strategy(debug_strategies[i])`,
     `_start_new_game()` (aunque la partida esté en curso; es depuración) y
     `_ui.set_debug_text("Estrategia: <nombre del archivo>")`;
   - `high_piece_requested` → `_state.debug_set_current(catalog.get_by_level(max − 1))`,
     para llegar a la victoria en minutos y revisar el arte de los niveles altos;
   - `overlay_toggled` → alterna un overlay con FPS, número de piezas y
     semilla. Lo refresca un `Timer` de 0,25 s en `Main` (hijo creado en
     `_compose`), activo solo mientras el overlay está visible; en cada
     `timeout`, `Main` llama a `_ui.set_debug_text(...)`.
4. `GameState.debug_set_current` emite `current_piece_changed` (la vista previa
   y `DropSystem` ya reaccionan a esa señal).
5. **Simulación de balance** — `tools/balance_sim.gd` (directorio nuevo; añádelo
   a la estructura de `AGENTS.md`). `export_presets.cfg` no se versiona, así
   que excluir `tools/*` de la exportación se anota en el `README.md` como paso
   manual al crear el preset:
   - `extends SceneTree`; se ejecuta con
     `godot --headless --fixed-fps 60 -s tools/balance_sim.gd -- --games=5`
     (por defecto 5 semillas por estrategia);
   - para que sea rápida: **no** elimines nodos (`Main` los usa en `_compose`
     vía `@onready`); pon `process_mode = PROCESS_MODE_DISABLED` en `GameUI`,
     `EffectsLayer` y `DropPreview` antes de `add_child`, buscándolos con
     `find_child` por nombre (en la fase 5 pasan a `World/Stage/…`). Mide el
     tiempo real. Objetivo: la ejecución por defecto en menos de
     ~5 min. Si no se alcanza, baja el tope de tiempo por partida;
   - para cada preset de `piece/spawn/` y cada semilla `1..N`: instancia
     `main.tscn` con una copia de la config (`duplicate()`, `rng_seed` fijado),
     y un bot suelta en una X aleatoria (con su propio RNG sembrado) cada vez
     que `is_drop_ready()`;
   - termina cada partida en `GAME_OVER`, `VICTORY` o a los 10 min simulados
     (configurable con `--max-minutes`);
   - imprime CSV: `estrategia,semilla,resultado,soltadas,nivel_max,puntuacion,segundos`
     y una tabla resumen con medias por estrategia.
   - Es una medida de **dificultad relativa** entre estrategias con un jugador
     aleatorio, no de diversión. Documenta esto en la cabecera del script.
6. Ejecuta la simulación y guarda la salida resumida en
   `docs/notas_playtest.md` (sección "Simulación automática", con fecha y
   versión del commit). Las notas humanas se añaden en la fase 8.

### Tests

- `test_game_state.gd`: `debug_set_current` cambia el ACTUAL, no toca el
  PRÓXIMO y emite `current_piece_changed` una vez.
- `test_session_integration.gd`: `strategy_requested.emit(1)` en mitad de una
  partida deja la partida reiniciada (`PLAYING`, puntuación 0, sin piezas).
- `DebugController` no necesita tests propios (solo traduce input).

**Hecho cuando:** F1–F4 y F12 funcionan en el editor; la simulación termina y
produce su CSV.

**Commits:**
- `feat(debug): selector de estrategia, pieza alta y overlay de depuración`
- `feat(tools): simulación headless de balance por estrategia`

---

## Fase 2 — Placeholders de todos los assets

**Objetivo:** que cada asset del Anexo A exista **ya** como placeholder, con su
ruta, nombre, tamaño y formato definitivos. Las fases siguientes conectan el
juego a estos archivos; el usuario los irá sustituyendo por los definitivos uno
a uno, sin tocar nada más.

Los placeholders deben ser **feos pero útiles**: colores planos, formas simples
y legibles, que dejen ver si el encaje (tamaño, centrado, capas, transparencia)
es correcto. No intentan parecerse al arte final.

### Contrato

```gdscript
# tools/asset_spec.gd  (sin class_name; lo cargan con preload el generador y los tests)
extends RefCounted
## Lista única de assets esperados (Anexo A). Cada entrada:
## {"path": String, "kind": "texture" | "audio", "size": Vector2i (solo texturas),
##  "loop": bool (solo audio)}. Excepción: la música usa "path" sin extensión
##  y "extensions": ["wav", "ogg"] (ver la integración más abajo).
static func entries() -> Array[Dictionary]

# tools/generate_placeholders.gd
extends SceneTree
## Crea los placeholders que falten. Uso:
##   godot --headless -s tools/generate_placeholders.gd            (solo los que faltan)
##   godot --headless -s tools/generate_placeholders.gd -- --force (regenera todos)
##   godot --headless -s tools/generate_placeholders.gd -- --templates
##       (además escribe las plantillas guía para el artista en docs/plantillas/)
```

### Pasos

1. `tools/asset_spec.gd` con **todas** las entradas del Anexo A (sprites de
   materiales, escenario, interfaz, efectos y audio). Es la única fuente de
   verdad de rutas y tamaños: ni el generador ni los tests repiten números.
2. `tools/generate_placeholders.gd`, solo con la API de `Image` (funciona en
   `--headless`, donde no hay renderizado) y `AudioStreamWAV.save_to_wav()`.
   Antes de escribir un archivo comprueba si existe; si existe y no hay
   `--force`, lo salta y lo dice por consola. Al final imprime un resumen
   `creados / saltados`.
3. Contenido de cada placeholder:

   | Asset | Placeholder |
   | ----- | ----------- |
   | 8 materiales (512²) | Círculo de **410 px** centrado con el `color` del `.tres` de ese material (léelo de `piece_catalog.tres`), borde más oscuro de 8 px, un reflejo arriba-izquierda y el **número de nivel** grande en el centro, dibujado con rectángulos estilo 7 segmentos (la API de `Image` no dibuja texto). El margen exterior, transparente. Así se ve de inmediato si el relleno 0,8 y la rotación funcionan. |
   | `workshop_background.png` (2560×1440) | Degradado vertical marrón cálido con unas bandas horizontales más claras (estantes) en los laterales y el centro más oscuro, para comprobar que el recorte "cubrir" deja el centro libre. |
   | `jar_back.png` (880×1200) | Relleno oscuro azulado-marrón, liso, opaco. |
   | `jar_front.png` (1008×1264) | Paredes de 64 px a cada lado y base de 64 px en color latón/madera; **interior transparente**; dos franjas verticales blancas con alfa 0,1 como reflejo. Sirve para verificar que las paredes dibujadas coinciden con las de colisión (`--debug-collisions`). |
   | `alchemist_dropper.png` (256×256) | Embudo: trapecio latón con la boca abajo, centrado en X y pegado al borde inferior. |
   | `parchment_panel.png` (256×256) | Relleno beige con un borde de 32 px más oscuro, para ver el 9-slice. |
   | `sparkle.png` (64×64) | Estrella blanca de cuatro puntas con caída radial de alfa. |
   | `sfx_*.wav` | Tonos sintéticos cortos (44,1 kHz, 16 bits, mono): soltar = golpe grave 0,08 s; fusión = tono 0,15 s; fusión alta = dos tonos tipo campana; peligro = pulso grave de 1 s **con bucle**; derrota = tono descendente; victoria = arpegio ascendente; clic = 0,03 s. Volumen bajo e igualado. |
   | `bgm_workshop.wav` | Zumbido suave de 4 s con bucle. Es **WAV** porque Godot no puede escribir OGG; ver la nota de integración más abajo. |

4. Plantillas para el artista (con `--templates`): en `docs/plantillas/` (no se
   importa, `docs/` tiene `.gdignore`), una imagen por tamaño con las guías
   dibujadas: para los materiales, el círculo de 410 px, la cruz central y el
   margen sombreado; para `jar_front`, las zonas de pared y base y el interior
   marcado como "transparente". Se suben al repositorio.
5. **Antes de importar**, añade a `project.godot`:
   - `rendering/textures/canvas_textures/default_texture_filter` = Linear Mipmap;
   - `[importer_defaults]` de texturas con `mipmaps/generate = true`.
   (Los valores por defecto del importador solo se aplican a archivos que se
   importan por primera vez; por eso van aquí y no en la fase 3.)
   Comprueba que los `.import` generados tienen `mipmaps/generate=true`.
6. Ejecuta el generador y luego `godot --headless --path . --import`.
7. **Bucles de audio:** no confíes en que `save_to_wav` escriba el bucle en el
   WAV. Tras la primera importación, en los `.import` de `sfx_danger_loop.wav`
   y `bgm_workshop.wav` pon `edit/loop_mode=2` (Forward) y reimporta. Al
   sustituir el archivo por el definitivo con el mismo nombre, el `.import` se
   conserva y el bucle también.
8. Sube al repositorio los placeholders y sus `.import` (pesan poco).
9. Crea `docs/07_diseno_presentacion.md` (ver regla 6) con:
   - propósito y orden de capas (se amplía en las fases 3–8);
   - el **procedimiento de integración** de un asset definitivo (abajo);
   - una tabla **estado de assets**: archivo | placeholder / definitivo. El
     usuario o el agente la actualizan cada vez que se sustituye uno.
   Añádelo a la lista de documentos de `AGENTS.md` y `README.md`, y añade
   `docs/plantillas/` a la descripción de `docs/` en la estructura.

### Procedimiento de integración de un asset definitivo

1. Exportar el archivo con **el mismo nombre, ruta, tamaño y formato** que su
   placeholder (Anexo A) y sobrescribirlo.
2. `godot --headless --path . --import`.
3. Ejecutar la suite: `test_asset_spec.gd` falla si el tamaño o el formato no
   coinciden.
4. Revisar en el juego (F4 de la fase 1 para los materiales altos) y marcarlo
   como "definitivo" en la tabla de `07`.

Excepciones, que requieren cambiar **una línea** de un `.tres`:
- **Música en OGG:** sustituir la referencia de `music` en `ui/sound_set.tres`
  por `bgm_workshop.ogg`, borrar `bgm_workshop.wav` y su `.import`, y activar
  `loop` en el `.import` del OGG. `test_asset_spec.gd` acepta para la música
  cualquiera de las dos extensiones (la entrada de `asset_spec.gd` la declara
  como `bgm_workshop` con `"extensions": ["wav", "ogg"]`), así que no hay que
  tocar ni la especificación ni el test.
- **Fuente:** no hay placeholder (se usa la fuente por defecto de Godot);
  al añadirla, se asigna en `ui/theme.tres` (fase 8).

### Tests

- `tests/unit/test_asset_spec.gd` (nuevo), recorriendo `asset_spec.gd`:
  - cada archivo existe (`ResourceLoader.exists`);
  - las texturas cargan como `Texture2D` y su tamaño es exactamente el de la
    especificación;
  - el audio carga como `AudioStream`; si la entrada tiene `loop`, el stream
    tiene el bucle activado (`AudioStreamWAV.loop_mode != LOOP_DISABLED` u
    `AudioStreamOggVorbis.loop`);
  - las entradas con `"extensions"` (solo la música) pasan si existe el archivo
    con alguna de ellas.
- El generador no tiene tests propios: lo cubre `test_asset_spec.gd` sobre su
  salida.

**Hecho cuando:** el generador crea todos los archivos, una segunda ejecución
sin `--force` no sobrescribe ninguno y `test_asset_spec.gd` pasa.

**Commit:** `feat(assets): placeholders generados con las rutas y tamaños definitivos`

---

## Fase 3 — Sprites de los materiales

**Objetivo:** que `PieceData.texture` (que ya existe) produzca un resultado
correcto con arte real. Hoy, con textura, `draw_piece` sigue pintando encima el
borde, el reflejo y el número de nivel, lo que taparía el arte.

### Contrato

```gdscript
# piece/piece_visual.gd
## Fracción del lienzo que ocupa el cuerpo redondo del sprite (Anexo A.1).
## El diámetro físico (2·radius) corresponde a esa fracción; el resto del
## lienzo es margen para destellos y cristales que sobresalen.
const TEXTURE_BODY_FILL: float = 0.8
## Si es false, el sprite se mantiene derecho aunque la pieza ruede
## (la luz pintada en el arte no gira).
@export var rotate_texture: bool = true

# piece/piece_catalog_validator.gd (regla nueva)
# Si texture != null y su ancho != alto → error "<id>: la textura debe ser cuadrada".
```

### Pasos

1. `PieceVisual.draw_piece` con `data.texture != null`:
   - mantiene el halo (`_draw_halo`) detrás, tal cual;
   - dibuja la textura en un cuadrado de lado `2 · radius / TEXTURE_BODY_FILL`
     centrado, modulada por `alpha`;
   - **no** dibuja el círculo plano, el borde, el reflejo ni el número;
   - sin textura, todo sigue exactamente como ahora.
2. `PieceVisual._process`: con textura, `global_rotation = 0` solo si
   `rotate_texture` es `false`. Sin textura, como ahora (siempre derecha).
   Deja `rotate_texture = true` en `piece.tscn`; la decisión final se toma
   jugando (ver "Decisiones abiertas").
3. Filtrado: los iconos de la leyenda (24 px) y la vista previa reducen sprites
   de 512 px. Los mipmaps y el filtro ya se configuraron en la fase 2;
   comprueba en una captura que la leyenda se ve limpia.
4. Asigna a cada `piece/data/<id>.tres` su placeholder
   `assets/sprites/pieces/<id>.png` (fase 2). Revisa una captura, con F4
   (fase 1) para los niveles 6–8: el círculo del placeholder debe coincidir con
   la colisión (`--debug-collisions`) y el número debe girar o no según
   `rotate_texture`.
5. Amplía `docs/07_diseno_presentacion.md` con la convención de sprites del
   Anexo A.1 (lienzo, relleno 0,8, rotación) y qué dibuja el código frente a
   qué trae el arte (halo por código, resto en el sprite).

### Tests (`tests/unit/`)

- `test_piece_visual.gd` (nuevo):
  - `draw_piece` con una `ImageTexture` cuadrada creada en memoria no falla.
    Las llamadas `draw_*` solo valen dentro de `_draw`: crea un `Node2D` en el
    árbol, conecta su señal `draw` a una lambda que llame a
    `PieceVisual.draw_piece(node, data, Vector2.ZERO, 30.0)`, llama a
    `queue_redraw()` y espera un frame de proceso;
  - con `rotate_texture = false` y textura, tras girar la pieza y esperar un
    frame, `visual.global_rotation` es 0; con `true`, sigue a la pieza.
- `test_piece_catalog_validator.gd`: textura no cuadrada → error; cuadrada o
  `null` → sin error.
- `test_real_data.gd`: cada material tiene textura y su ruta es
  `assets/sprites/pieces/<id>.png` (así el placeholder o el definitivo siempre
  están conectados).

**Hecho cuando:** con los placeholders, cada pieza se ve sin borde dibujado por
código, el halo asoma por detrás en los niveles con brillo y el círculo encaja
con la colisión.

**Commit:** `feat(visual): soporte de sprites para materiales con relleno y rotación configurables`

---

## Fase 4 — Escenario: taller, recipiente y artefacto

**Objetivo:** sustituir el fondo plano y las paredes de madera dibujadas por el
taller y el frasco de cristal de la referencia, manteniendo el *fallback*
procedural.

Hoy `Board._draw` mezcla física (paredes) con dibujo placeholder. Esta fase
saca el dibujo a nodos de presentación propios, igual que `Piece` delega en
`PieceVisual`.

### Contrato

```gdscript
# board/board_skin.gd
class_name BoardSkin
extends Resource
## Aspecto del recipiente. Todas las texturas son opcionales (Anexo A.2).
@export var back_texture: Texture2D    # interior del frasco, detrás de las piezas
@export var front_texture: Texture2D   # paredes, suelo y reflejos, delante de las piezas
@export var danger_color: Color = Color(0.91, 0.2, 0.24, 0.8)

# board/board_visual.gd
class_name BoardVisual
extends Node2D
## Dibuja una capa del recipiente (detrás o delante de las piezas).
enum Layer { BACK, FRONT }
@export var layer: Layer = Layer.BACK
@export var skin: BoardSkin
func setup(config: GameConfig) -> void

# ui/drop_preview.gd (añadido)
## Sprite opcional del artefacto del alquimista, sobre la pieza ACTUAL.
@export var dropper_texture: Texture2D
## Lado en px de juego con el que se dibuja (el PNG es de 256: 4× de resolución).
@export var dropper_size: float = 64.0
```

### Pasos

1. `board.tscn`: nodos `BackVisual` (antes de `Pieces`) y `FrontVisual`
   (después de `Pieces`), ambos `BoardVisual` con el mismo `board_skin.tres`
   (en `board/`), que apunta a los placeholders `jar_back.png` y
   `jar_front.png` de la fase 2. `Board.setup` llama a `setup(config)` de los dos.
2. Mueve el dibujo actual de `Board._draw` a `BoardVisual`:
   - `BACK`: con `back_texture`, la dibuja en el rectángulo interior; sin ella,
     el fondo de color actual. La línea de peligro se dibuja aquí, encima.
   - `FRONT`: con `front_texture`, la dibuja en el rectángulo exterior
     (Anexo A.2), que empieza en `y = 0`; sin ella, las paredes de madera
     actuales. Las paredes de colisión suben `EXTENSION_ABOVE` (400 px) por
     encima de la boca del frasco y esa parte queda **invisible a propósito**
     con textura: es una barrera para pilas que sobresalen, y la partida se
     pierde antes de que importe. Anótalo en `07`; al comparar con
     `--debug-collisions`, solo cuenta la parte desde `y = 0`.
   - `Board` deja de tener `_draw` y constantes de color.
3. Fondo del taller: en `main.tscn`, un `CanvasLayer` `Background` (layer −1)
   con un `TextureRect` a pantalla completa, `expand_mode = ignore size`,
   `stretch_mode = keep aspect covered`, textura
   `assets/sprites/scene/workshop_background.png` (placeholder de la fase 2).
   Sin textura, el color de fondo del proyecto.
4. Artefacto (`dropper_texture`): `DropPreview` lo dibuja como un cuadrado de
   `dropper_size` px centrado en `aim_x`, justo encima de la pieza ACTUAL (su
   borde inferior a `spawn_y − radius`), también durante el cooldown. Con 64 px
   y la pieza generable más grande (radio 46) su borde superior queda en
   `y = −70` del tablero, es decir, a 10 px del borde de la pantalla
   (`World` está en `y = 80`); con la pieza de F4 (radio 68) se recorta un poco,
   y se acepta porque es solo depuración. En `main.tscn` se asigna
   el placeholder `alchemist_dropper.png`. Sin textura, nada.
5. Documenta en `07_diseno_presentacion.md` las capas (fondo → interior →
   piezas → frente → efectos → UI) y el Anexo A.2.

### Tests

- `test_board.gd`: tras `setup`, `Board` sigue teniendo las tres paredes y la
  zona de peligro (la refactorización no rompe la física); `BackVisual` va
  antes de `Pieces` y `FrontVisual` después en el orden de hijos.
- `test_board_visual.gd` (nuevo): con `skin` nulo o texturas nulas,
  `setup` + un frame no fallan, en ambas capas.
- `test_real_data.gd`: `board_skin.tres` apunta a `jar_back.png` y
  `jar_front.png`.

**Hecho cuando:** con `--debug-collisions`, las paredes del placeholder
`jar_front.png` coinciden con las de colisión.

**Commit:** `feat(escenario): BoardSkin con capas delante y detrás, fondo del taller y artefacto`

---

## Fase 5 — Game feel

**Objetivo:** que cada fusión se note. Todo en presentación; la simulación solo
expone lo que falte como señal.

### Contrato

```gdscript
# systems/progress_system.gd (añadido)
## Puntos sumados por una fusión y dónde ocurrió (para el texto flotante).
## Así la presentación no duplica la regla de puntuación.
signal points_awarded(amount: int, position: Vector2)

# piece/piece_visual.gd (añadido)
## Animación de aparición (escala 0,6 → 1 con rebote, ~0,15 s). Solo visual:
## la forma de colisión tiene el tamaño completo desde el primer frame.
func play_pop_in() -> void

# ui/screen_shake.gd
class_name ScreenShake
extends Node
func setup(target: Node2D, merge_system: MergeSystem) -> void
```

### Pasos

1. `ProgressSystem` emite `points_awarded` en ambos casos (fusión normal con
   `result.score_value` y fusión máxima con `victory_bonus`). `add_score`
   devuelve `void`, así que `ProgressSystem` comprueba `_state.is_playing()`
   **antes** de llamar a `add_score` y no emite si no lo está. En la fusión
   máxima, emite antes de `set_victory()` (después ya no está en `PLAYING`).
2. **Aparición con rebote:** `Piece._ready` llama a `_visual.play_pop_in()` si
   `state == State.ACTIVE` (las piezas nacidas de fusión). Usa un `Tween` sobre
   `scale` del `Visual`.
3. **Texto flotante:** `EffectsLayer` escucha `points_awarded` y dibuja
   `+N` que sube ~40 px y se desvanece en ~0,8 s (con la fuente del tema si
   existe). `EffectsLayer` está en 174 líneas: si al añadirlo pasa de ~300,
   separa los textos flotantes en `ui/floating_text_layer.gd`.
4. **Partículas de fusión:** pequeña ráfaga (`CPUParticles2D`, ~16) con el color
   del resultado; la cantidad crece con el nivel. Textura de partícula:
   `assets/sprites/fx/sparkle.png` (placeholder de la fase 2), exportada en
   `EffectsLayer` para poder dejarla en `null`.
5. **Sacudida:** en `main.tscn`, inserta un `Node2D` `Stage` entre `World` y
   **todos** sus hijos (`World/Stage/Board`, `World/Stage/DropPreview`,
   `World/Stage/EffectsLayer`: todo se sacude junto; actualiza las rutas de
   `main.gd` y las de los tests que las usen). `Main`
   sigue moviendo `World`; `ScreenShake` desplaza solo `Stage` con un ruido
   que decae en ~0,25 s. Intensidad: 0 para fusiones normales, pequeña para
   las **fusiones altas**, grande en la victoria (`max_level_merged`).
   **Fusión alta** se define una sola vez, por datos: el material **resultante**
   tiene `glow_strength >= PieceVisual.PULSE_MIN_GLOW` (hoy, los niveles 6 y 7
   como resultado). `ScreenShake` y `AudioDirector` (fase 6) usan esa misma
   comprobación; no escribas el número 6 en el código. `request_aim_global` ya convierte con
   `Board.to_local`, así que el apuntado sigue siendo correcto.
6. **Opcional, si queda claro al jugar:** la línea guía de `DropPreview` se
   detiene en la primera pieza que tocaría (consulta de solo lectura
   `PhysicsDirectSpaceState2D.cast_motion` con un círculo del radio actual).
   Si se hace, va en `DropPreview`, no en `DropSystem`.
7. Documenta cada efecto, su disparador y su duración en
   `07_diseno_presentacion.md`.

### Tests

- `test_progress_system.gd`: `points_awarded` lleva el `score_value` del
  resultado y la posición; en la fusión máxima lleva `victory_bonus`; fuera de
  `PLAYING` no se emite.
- `test_piece.gd`: una pieza creada en `ACTIVE` termina con `Visual.scale == ONE`
  tras ~0,3 s; su forma de colisión tiene el radio completo desde `_ready`.
- `test_merge_integration.gd` sigue pasando (la aparición no afecta a la física).

**Commit:** `feat(feel): rebote de aparición, puntos flotantes, partículas y sacudida`

---

## Fase 6 — Audio

**Objetivo:** sonido para cada evento y música de taller, con silencio como
*fallback* para lo que falte.

### Contrato

```gdscript
# ui/sound_set.gd
class_name SoundSet
extends Resource
## Sonidos del juego (Anexo A.4). Todos opcionales.
@export var drop: AudioStream
@export var merge: AudioStream            # se varía el tono por nivel
@export var merge_high: AudioStream       # niveles ≥ 6; si es null, se usa merge
@export var danger_loop: AudioStream
@export var game_over: AudioStream
@export var victory: AudioStream
@export var ui_click: AudioStream
@export var music: AudioStream

# ui/audio_director.gd
class_name AudioDirector
extends Node
func setup(state: GameState, drop_system: DropSystem, merge_system: MergeSystem,
		danger_system: DangerSystem, sounds: SoundSet) -> void
## Silencia o restaura el bus Master.
func toggle_mute() -> void
## Último stream elegido para una fusión (para los tests; `null` si ninguno).
func get_last_merge_stream() -> AudioStream
## Indica si el bucle de peligro está sonando.
func is_danger_playing() -> bool
```

### Pasos

1. `default_bus_layout.tres` con buses `Music` y `SFX` bajo `Master`.
2. `AudioDirector` (nodo en `main.tscn`). `ui/sound_set.tres` apunta a los
   placeholders `sfx_*.wav` y `bgm_workshop.wav` de la fase 2:
   - `piece_dropped` → `drop`;
   - `pieces_merged` → `merge` con `pitch_scale` que baja con el nivel
     (piezas grandes suenan graves), o `merge_high` si es una **fusión alta**
     (misma definición que en la fase 5, sobre el material resultante);
   - `danger_changed(ratio)` → `danger_loop` con volumen proporcional a
     `ratio`; se detiene en 0;
   - `status_changed` → `game_over` o `victory`; la música baja (*duck*) en
     las pantallas de fin;
   - música en bucle desde el arranque.
   Usa varios `AudioStreamPlayer` (o `max_polyphony`) para que las cascadas no
   corten sonidos.
3. Acción `toggle_mute` (M) en el InputMap; `DropController` emite
   `mute_requested` y `Main` la conecta a `AudioDirector.toggle_mute`.
4. Los botones de las pantallas de fin reproducen `ui_click`
   (`GameUI` emite una señal o `AudioDirector` se conecta a los botones vía
   `Main`; elige lo más simple y anótalo).
5. Documenta en `07_diseno_presentacion.md` la tabla evento → sonido y añade
   el control M a `04_gameplay_design.md` §4.

### Tests

- `test_audio_director.gd` (nuevo), con un `SoundSet` de `AudioStreamGenerator`
  o todo `null`:
  - con todo `null`, emitir cada señal no falla;
  - una fusión de nivel alto deja `get_last_merge_stream() == merge_high`, y
    una de nivel bajo, `merge`;
  - `danger_changed(0.5)` → `is_danger_playing()`; `danger_changed(0)` lo
    detiene;
  - `toggle_mute` alterna `AudioServer.is_bus_mute(0)` (restáuralo en
    `after_each`).
- `test_real_data.gd`: `sound_set.tres` tiene todos sus campos asignados.

**Commit:** `feat(audio): AudioDirector con SoundSet, buses y silencio con M`

---

## Fase 7 — Sesión: título, pausa y récord

### Contrato

```gdscript
# game/score_store.gd
class_name ScoreStore
extends RefCounted
## Récord local persistido con ConfigFile. Sin autoload: lo crea Main.
signal best_changed(best: int)
## Emitida por `submit` cuando bate el récord (después de `best_changed`).
signal new_record(score: int)
## `path` vacío → solo en memoria, nunca escribe a disco.
func _init(path: String) -> void
func get_best() -> int
## Guarda si supera el récord. Devuelve true si es un récord nuevo.
func submit(score: int) -> bool

# game/main.gd (añadidos)
## false en los tests: la partida arranca sin pantalla de título.
@export var show_title: bool = true
## Ruta del récord. Vacía → récord solo en memoria (la usan los tests).
@export var records_path: String = "user://records.cfg"
# Firma nueva del arranque: `with_title` decide si se queda en READY.
func _start_new_game(with_title: bool) -> void

# ui/drop_controller.gd (añadida; no conoce el estado)
signal pause_requested

# ui/audio_director.gd (añadido)
## Pausa el bucle de peligro y baja la música; `false` lo restaura.
func set_paused(paused: bool) -> void

# ui/game_ui.gd (añadidos; el botón "Reiniciar partida" de la pausa reutiliza
# la señal existente `restart_requested`)
signal resume_requested
signal start_requested       # botón de la vista de título
## `scores` opcional: con `null` no se muestra el récord.
func setup(state: GameState, catalog: PieceCatalog, scores: ScoreStore = null) -> void
func set_paused(paused: bool) -> void
```

### Pasos

1. **Récord:** `Main` crea `ScoreStore.new(records_path)`. Al pasar a
   `GAME_OVER` o `VICTORY`, `Main` llama a `submit(score)`. `GameUI` muestra
   "Récord: N" en el HUD (escucha `best_changed`) y una etiqueta
   "¡Nuevo récord!" en las vistas de fin, que se oculta al mostrar la vista y
   se hace visible al recibir `new_record`. **Orden:** `GameUI` se conecta a
   `status_changed` antes que `Main` (su `setup` va antes en `_compose`), así
   que la vista de fin ya está visible cuando llega `new_record`; la etiqueta
   no depende de ese orden. Un archivo corrupto o ausente equivale a récord 0,
   nunca a un error.
   - **Todos** los tests que instancian `main.tscn` ponen
     `_main.records_path = ""` antes de `add_child`, para no tocar el récord
     real del usuario.
   - `test_game_ui.gd` sigue llamando a `setup(_state, _catalog)`; el
     parámetro nuevo es opcional.
2. **Título:** `_start_new_game(with_title)` hace el reinicio de siempre y
   solo llama a `_state.start()` si `with_title` es `false`. Llamadas:
   - `_ready` → `_start_new_game(show_title)`;
   - reinicio desde Game Over, Victoria o la pausa → `_start_new_game(false)`;
   - F1–F3 (fase 1) → `_start_new_game(false)` (la depuración no muestra el
     título).
   Con el estado en `READY`, `GameUI` muestra la vista de título (nombre,
   subtítulo "De la basura a la Piedra Filosofal", "Clic o Espacio para
   empezar"). **Cómo se empieza, sin que el controlador conozca reglas:**
   `DropController` sigue emitiendo solo `drop_requested`. `Main` conecta
   `drop_requested` a un callback propio que, si el estado es `READY`, llama
   a `_state.start()` y **no** reenvía la orden; si el árbol está pausado
   (`get_tree().paused`), la ignora; si no, llama a
   `_drop_system.request_drop()`. El filtro de `DropController` en pausa es
   una primera barrera, pero la que cuenta es esta: las señales llaman a los
   métodos aunque el nodo esté pausado. El botón de la vista de título emite
   `GameUI.start_requested` → el mismo `_state.start()`. Así el clic que
   empieza nunca suelta una pieza; compruébalo con un test.
   - Que `Main` mire `READY` no viola la regla de "sin `if` sobre reglas en
     `Main`" si la consulta vive en `GameState`: añade
     `GameState.is_ready() -> bool` y úsala.
   - Actualiza los tests de integración que instancian `main.tscn` para poner
     `_main.show_title = false` antes de `add_child`.
   - Haz lo mismo en `tools/balance_sim.gd` (fase 1): `show_title = false` y
     `records_path = ""`. Sin lo primero, todas las partidas simuladas se
     quedarían en `READY` sin soltar nada hasta el tope de tiempo; sin lo
     segundo, escribiría en el récord real. Comprueba tras el cambio que la
     simulación sigue produciendo partidas con soltadas > 0.
   - `04` §15 ya prevé `READY` para esto; actualiza el texto ("queda
     disponible para…" → describe la pantalla de título).
3. **Pausa** (acción `pause`, Esc y P):
   - motor primero: `get_tree().paused`. `Main` solo pausa si
     `_state.is_playing()`. Al pausar o reanudar, `Main` pone
     `get_tree().paused` y llama a `_ui.set_paused(p)` y
     `_audio_director.set_paused(p)` (nadie más consulta el árbol);
   - `GameUI`, `DropController` y `AudioDirector` con
     `process_mode = PROCESS_MODE_ALWAYS`; lo demás se detiene solo;
   - `DropController`, mientras `get_tree().paused`, solo emite
     `pause_requested` (ni apuntar ni soltar: las llamadas directas a
     `DropSystem` funcionarían aunque esté pausado);
   - vista de pausa con "Continuar" (`resume_requested`) y "Reiniciar partida"
     (`restart_requested`, la señal que ya existe). Reiniciar desde la pausa es
     una regla nueva: la guarda de `Main._on_restart_requested`
     (`main.gd:118`, hoy `if _state.is_finished()`) pasa a
     `if _state.is_finished() or get_tree().paused`; en ese caso `Main`
     despausa (y avisa a UI y audio) antes de `_start_new_game(false)`.
     La tecla R sigue sin hacer nada en pausa (`DropController` solo emite
     `pause_requested`).
     Actualiza `04` §4 (controles) y §14 (reinicio también desde la pausa);
   - al perder el foco de la ventana
     (`NOTIFICATION_APPLICATION_FOCUS_OUT`) se pausa automáticamente;
   - la música sigue sonando más baja durante la pausa. `AudioDirector` es
     `ALWAYS`, así que el bucle de peligro no se detiene solo:
     `set_paused(true)` le pone `stream_paused = true` y baja la música;
     `set_paused(false)` lo deshace.
4. Documenta las pantallas (título, HUD, pausa, fin) en
   `07_diseno_presentacion.md`.

### Tests

- `test_score_store.gd` (nuevo, ruta `user://test_records.cfg` borrada en
  `after_each`): récord inicial 0; `submit` mayor → `true`, persiste y otra
  instancia con la misma ruta lo lee; `submit` menor o igual → `false`;
  archivo corrupto → 0.
- `test_session_integration.gd`:
  - con `show_title = true`, tras `_ready` el estado es `READY` y no hay
    piezas; `DropController.drop_requested` → `PLAYING`, y sigue sin haber
    piezas; un segundo `drop_requested` sí crea una;
  - pausa: `pause_requested` en `PLAYING` → `get_tree().paused`; un
    `drop_requested` en pausa no crea piezas; otro `pause_requested` despausa
    (restaura siempre `paused = false` en `after_each`);
  - `pause_requested` en `GAME_OVER` no pausa;
  - `restart_requested` en pausa reinicia y deja `get_tree().paused == false`;
  - con `records_path = ""`, al terminar una partida con puntos se emite
    `new_record` y la etiqueta "¡Nuevo récord!" de la vista de fin queda
    visible.

**Commits:**
- `feat(sesión): récord local persistente`
- `feat(sesión): pantalla de título y pausa`

---

## Fase 8 — Interfaz con tema y balance

### Pasos — interfaz

1. `ui/theme.tres` aplicado a `GameUI/Root`. **Quita antes** los
   `theme_override_styles/panel` de `GameOverView` y `VictoryView` en
   `game_ui.tscn` (líneas 98 y 133): un override local gana al tema y el
   pergamino nunca se vería. Mueve ese `StyleBoxFlat` al tema como el estilo
   `panel` de `PanelContainer` (es el *fallback* si la textura es `null`).
   Contenido del tema: fuente del Anexo A.3 (si está),
   tamaños, `StyleBoxTexture` de pergamino (9-slice) para las vistas de fin,
   pausa y título, con el placeholder `parchment_panel.png` de la fase 2
   (márgenes de 9-slice de 32 px); si la textura es `null`, el `StyleBoxFlat`
   actual. La fuente queda sin asignar hasta que el usuario la añada (ver la
   excepción en la fase 2).
2. Leyenda de rareza como en la referencia: icono, nombre y una etiqueta de
   rareza con color. `rarity_label` y la leyenda ya existen (iteración 1); lo
   único nuevo es el color de la etiqueta, que es dato de presentación del
   material:
   añade `@export var rarity_color: Color` a `PieceData` (grupo
   Presentation), rellénalo en los 8 `.tres` con los colores de la imagen de
   referencia y documéntalo en `03` §3.1.
3. Comprueba la composición a 1280×720, 1920×1080 y 2560×1080 (capturas con
   `--resolution`). Con `stretch/aspect = expand` los paneles laterales deben
   seguir anclados y el fondo cubrir toda la ventana.

### Pasos — balance (requiere al usuario)

4. El agente **no inventa sensaciones**. Prepara en `docs/notas_playtest.md`
   una plantilla por partida: estrategia, duración, nivel máximo, puntuación,
   ¿se llegó a la victoria?, momentos frustrantes, y pide al usuario que juegue
   al menos 3 partidas por estrategia (F1–F3).
5. Con las notas humanas y la simulación de la fase 1, propone cambios **solo
   de datos** (`GameConfig`, `piece.tscn`, presets) con su motivo. Candidatos a
   vigilar: `game_over_delay` (1 s es corto comparado con Suika),
   `drop_cooldown`, `bounce`, y si la estrategia por defecto debe cambiar.
   Cada cambio se anota en las notas y en el `03` correspondiente.

### Tests

- `test_real_data.gd`: todos los materiales tienen `rarity_color` con alfa > 0.
- `test_game_ui.gd`: la leyenda crea una fila por material con la etiqueta de
  rareza coloreada.

**Commits:**
- `feat(ui): tema, pergamino y leyenda de rareza con color`
- `docs(playtest): notas de balance de la iteración 2`
- `balance(config): …` (si las pruebas lo piden)

---

## Fase 9 — Opcionales (solo si el usuario los pide)

- **Logro "Magnum Opus"** (primera victoria): igual que en `05` fase 9, pero
  reutilizando el patrón de `ScoreStore` (mismo archivo de usuario, otra
  sección).
- **Bonificación por cascada:** `04` §16 la deja fuera de la primera versión.
  Requiere decisión de diseño (fórmula, si se muestra un contador "×N").
  `MergeSystem` ya resuelve en orden por paso de física; la cascada se puede
  detectar en `ProgressSystem` contando fusiones encadenadas en una ventana de
  tiempo. No la implementes sin la fórmula aprobada.
- **Táctil / web:** si el objetivo incluye móvil o navegador, apuntar con el
  dedo (`InputEventScreenDrag`) y soltar al levantarlo, y un diseño vertical.
  Implica rehacer la composición de `GameUI`; planificar aparte.
- **Shader de brillo** para los niveles 6–8 (sustituye o complementa el halo
  por círculos) si el arte lo pide.

---

## Decisiones abiertas (para el usuario)

| Decisión | Recomendación por defecto | Cuándo decidir |
| -------- | ------------------------- | -------------- |
| ¿Los sprites giran con la pieza? | Sí, si el arte no tiene una luz muy marcada; si la tiene, `rotate_texture = false`. Probar ambas con el arte real. | Al integrar los sprites (fase 3) |
| ¿Se muestra el número de nivel sobre los sprites? | No (Suika no lo hace; la leyenda y el tamaño bastan). | Fase 3 |
| ¿Pantalla de título? | Sí, mínima. | Fase 7 |
| Bonificación por cascada | Fuera de esta iteración salvo petición. | Fase 9 |
| Plataforma objetivo (escritorio / web / móvil) | Escritorio; lo demás, otra iteración. | Antes de la fase 9 |

---

## Anexo A — Especificación de assets

Cada archivo de esta lista existe desde la fase 2 como **placeholder** con su
nombre, tamaño y formato definitivos, y el juego ya lo usa. Para integrar el
definitivo basta con sobrescribirlo respetando nombre, tamaño y formato, y
reimportar (procedimiento completo en la fase 2). `test_asset_spec.gd`
comprueba que se cumple. Las plantillas con las guías dibujadas están en
`docs/plantillas/`.

Formato de imagen: **PNG con transparencia**, también el fondo. Nombres exactos
en `snake_case`.

### A.1. Materiales (8 sprites) — `assets/sprites/pieces/`

| Archivo | Material | Radio en juego |
| ------- | -------- | -------------- |
| `trash.png` | Basura | 16 px |
| `scrap_metal.png` | Metal común | 22 px |
| `copper.png` | Cobre | 29 px |
| `silver.png` | Plata | 37 px |
| `gold.png` | Oro | 46 px |
| `enchanted_gold.png` | Oro encantado | 56 px |
| `celestial_matter.png` | Material celestial | 68 px |
| `philosopher_stone.png` | Piedra Filosofal | 82 px |

- **Lienzo:** 512 × 512 px, todos iguales, fondo transparente.
- **Cuerpo:** una esfera (o poliedro muy redondo) **centrada**, de **410 px de
  diámetro** (80 % del lienzo). La colisión es un círculo exacto: lo que se
  salga del círculo de 410 px parecerá que atraviesa a las demás piezas.
- **Margen exterior (51 px por lado):** solo para adornos que pueden solaparse
  con las vecinas: destellos, cristales flotantes del nivel 6–7, el anillo de
  la Piedra Filosofal. Mantenerlos finos y semitransparentes.
- **Sin sombra proyectada ni fondo**, y sin brillo exterior difuso grande: el
  halo lo dibuja el código según `glow_strength`, y se vería doble.
- **Luz:** suave y frontal, o arriba-izquierda poco marcada. Si las piezas
  giran, una luz muy direccional se verá girar con ellas.
- **Legibilidad a 32 px:** la Basura se verá a 32 px de diámetro. Silueta y
  color tienen que distinguir cada material aunque se pierda el detalle; los
  niveles 1–3 opacos y sin brillo, el brillo empieza en el 4 (concepto,
  "Cómo comunicar el valor").
- Estilo: el de la referencia (`docs/El Alquimista Pobre_ De Basura a
  Leyenda.png`), facetado *low-poly* pintado.

### A.2. Escenario — `assets/sprites/scene/`

| Archivo | Tamaño | Contenido |
| ------- | ------ | --------- |
| `workshop_background.png` | 2560 × 1440 | Taller de madera cálido. Se recorta para cubrir la ventana, así que lo importante va en el centro. El centro (donde está el frasco, ~1010 × 1420 px a esta escala) debe ser oscuro y con poco detalle para no competir con las piezas. |
| `jar_back.png` | 880 × 1200 | Interior del frasco a escala 2× (el interior en juego mide 440 × 600). Cristal oscuro, opaco o casi; sin bordes. |
| `jar_front.png` | 1008 × 1264 | Paredes, base y reflejos a escala 2×. El exterior en juego mide 504 × 632: paredes de 32 px a cada lado y base de 32 px. **El interior (desde x = 64 hasta x = 944, y de 0 a 1200) debe ser transparente**, salvo reflejos verticales muy sutiles (alfa ≤ 15 %). Boca abierta arriba. |
| `alchemist_dropper.png` | 256 × 256 | Opcional. El artefacto que sostiene el material actual (embudo de latón, pinza, alambique…). Su borde inferior se coloca justo encima de la pieza. |

### A.3. Interfaz — `assets/ui/` y `assets/fonts/`

| Archivo | Tamaño | Contenido |
| ------- | ------ | --------- |
| `parchment_panel.png` | 256 × 256 | Pergamino para paneles, con bordes de ~32 px (se estira como 9-slice: las esquinas no se deforman, el centro sí). |
| Fuente del título y HUD | — | Una fuente **con licencia OFL** de Google Fonts, parecida a la del cartel de la referencia (redondeada y gruesa, p. ej. Fredoka o Baloo 2). Mejor descargar que generar. Guardar en `assets/fonts/` con su `OFL.txt`. |
| `assets/sprites/fx/sparkle.png` | 64 × 64 | Destello blanco sobre transparente (el código le da color). |

### A.4. Audio — `assets/audio/`

Efectos en **WAV** (44,1 kHz, 16 bits, mono, sin silencio al principio);
música en **OGG** (estéreo, bucle sin cortes). Volumen de los efectos
aproximadamente igualado entre sí.

| Archivo | Uso |
| ------- | --- |
| `sfx_drop.wav` | Soltar (corto, ~0,1 s). |
| `sfx_merge.wav` | Fusión normal; el código varía el tono por nivel. |
| `sfx_merge_high.wav` | Fusión de nivel ≥ 6: más mágico (campanas, cristal). |
| `sfx_danger_loop.wav` | Bucle de advertencia (pulso grave, ~1 s, sin cortes). |
| `sfx_game_over.wav` | Derrota (~1–2 s). |
| `sfx_victory.wav` | Victoria (~2–3 s). |
| `sfx_ui_click.wav` | Botones. |
| `bgm_workshop.ogg` | Música del taller, 1–3 min en bucle, tranquila. Su placeholder es `bgm_workshop.wav` (excepción de la fase 2: al integrarla se cambia una línea de `ui/sound_set.tres`). |

---

## Desviaciones

*(El agente implementador anota aquí cualquier cambio respecto a esta guía,
con su motivo y la fase en que ocurrió.)*

1. **Fase 2 — `AssetSpec.resolve_path` y división del generador.** Se añade
   `AssetSpec.resolve_path(entry) -> String` (resuelve las `extensions` de la
   música y devuelve `""` si falta el archivo) para que el generador y el test
   no repitan esa lógica. El dibujo se reparte en `tools/placeholder_images.gd`
   y `tools/placeholder_audio.gd` (helpers estáticos sin `class_name`) para que
   `generate_placeholders.gd` quede corto. La API pública del contrato no cambia.
2. **Fase 4 — `BoardVisual` no llama a `Board`.** Las paredes de madera de
   respaldo calculan sus rectángulos dentro de `BoardVisual` (con
   `DangerZone.EXTENSION_ABOVE`) en lugar de pedírselos a `Board`: `Board`
   referencia `BoardVisual` y una llamada inversa crearía una referencia
   circular entre clases (la misma razón de la desviación 1 de la iteración 1).
3. **Fase 5 — API añadida.**
   - `EffectsLayer.setup(...)` recibe un quinto parámetro **opcional**
     `progress_system: ProgressSystem = null` para escuchar `points_awarded`; los
     tests existentes y los que no lo pasan siguen funcionando (sin texto
     flotante).
   - `PieceVisual.is_high_tier(data) -> bool` es la definición única de
     "fusión alta" (`glow_strength >= PULSE_MIN_GLOW`) que la sacudida y el
     audio comparten, como pide el plan (no escribir el número 6 en el código).
   - `ProgressSystem` no emite `points_awarded` cuando el importe es 0
     (`add_score` también lo ignora): un "+0" flotante no aporta nada.
4. **Fase 6 — clic de los botones.** Se elige la opción más simple: `GameUI`
   emite `button_pressed` al pulsar cualquier botón y `Main` lo conecta a
   `AudioDirector.play_ui_click()`. Ambos son API pública nueva, no prevista en
   el contrato. `Main` añade además `@export var sound_set: SoundSet` (asignado
   en `main.tscn`) y `get_audio_director()`.
5. **Fase 5 — línea guía que se detiene (paso 6, opcional).** No se
   implementa: el plan la condiciona a que "quede claro al jugar" y requiere
   partidas humanas.
