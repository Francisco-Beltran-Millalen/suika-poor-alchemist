# Plan de la iteración 3 (guía paso a paso)

Guía temporal para el agente implementador. **No es diseño canónico**: cuando una
fase cambia una regla, el cambio se escribe también en el documento canónico que
se indica en esa fase. Si esta guía y un documento canónico se contradicen, manda
el canónico y la discrepancia se anota en "Desviaciones", al final.

La iteración 2 (`06_plan_iteracion_2.md`) dejó el juego completo en escritorio:
título, pausa, récord, audio, *game feel* y placeholders de todos los assets, con
207 tests en verde. Esta iteración lo convierte en un juego **distribuible**:

1. salda la deuda pequeña que quedó (fuga de audio al salir, huérfanos en los
   tests, silencio en pausa);
2. añade opciones persistentes (volúmenes, silencio, pantalla completa);
3. prepara la distribución de escritorio (versión, icono, salir, créditos,
   *builds* de Linux y Windows);
4. adapta la pantalla a vertical y horizontal, y añade control táctil;
5. exporta a web (escritorio y móvil);
6. cierra el balance con las partidas humanas (fase **bloqueante**: espera las
   notas del usuario).

**Fuera de alcance:** arte, fuente y audio definitivos (los crea el usuario y se
integran con el procedimiento de `07` §7.1), exportación nativa a Android/iOS,
logros, bonificación por cascada y estadísticas.

---

## Paso previo — Reglas para el agente

1. Lee en este orden: `RULES.md`, `AGENTS.md`, `04_gameplay_design.md`,
   `03_data_design.md`, `02_technical_design.md`, `07_diseno_presentacion.md`,
   la sección "Desviaciones" de `06_plan_iteracion_2.md` y esta guía completa.
2. **Una fase cada vez.** No empieces la siguiente con tests en rojo.
3. Las firmas marcadas como **Contrato** son obligatorias. Puedes añadir
   métodos privados (`_x`); cualquier otra API pública nueva o cambiada se anota
   en "Desviaciones" en el mismo commit.
4. Si algo es imposible en el motor o contradice el diseño, **detente**, elige
   la alternativa más simple que respete la arquitectura y anótala.
5. Tipado estático en todo, orden interno según `RULES.md` §4, doc comments `##`
   en la API pública.
6. **Límite de 400 líneas** en código y documentación canónica.
   `02_technical_design.md` está en **380 líneas**: las filas nuevas de la tabla
   de componentes caben, pero cualquier texto largo va en `07`. `main.gd` está en
   237: si se acerca a 330, saca la responsabilidad a su componente (por eso
   existen `DisplayDirector` y `SettingsStore`).
7. La regla de dependencias no cambia: **Presentación → Simulación → Datos**.
   Ningún sistema de simulación conoce ajustes, ventanas, plataformas ni input
   táctil.
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
# Captura con otro tamaño de ventana (vertical, móvil, tableta…)
godot --path . --scene res://game/main.tscn --resolution 576x1024 \
      --write-movie /tmp/mov/shot.png --fixed-fps 60 --quit-after 120
```

Plantillas de exportación instaladas: **4.7.2.stable** (Linux, Windows y Web,
también las variantes `web_nothreads_*`), en
`~/.local/share/godot/export_templates/4.7.2.stable/`.

### Convenciones que siguen vigentes

Las de `05` §"Convenciones transversales" y `06` §"Convenciones que siguen
vigentes" (assets opcionales con `null`, nunca sobrescribir un asset del
usuario, rutas de assets, persistencia sin autoloads). Además:

- **Plataforma inyectada:** solo `Main` consulta `OS.has_feature(...)` y
  `DisplayServer.is_touchscreen_available()`. Los demás componentes reciben
  *flags* (`allow_quit`, `allow_fullscreen`, `touch_hints`) para que los tests
  puedan simular cualquier plataforma.
- **Tests que instancian `main.tscn`:** además de `show_title = false` y
  `records_path = ""`, ponen `settings_path = ""` (fase 1) antes de
  `add_child`. Lo mismo en `tools/balance_sim.gd`.
- **Salida de builds:** `dist/` (ya está en `.gitignore`). Nunca se sube.

---

## Fase 0 — Deuda pequeña

### Pasos

1. **Silencio también en pausa.** Hoy `DropController`, en pausa, solo emite
   `pause_requested`, así que `M` no hace nada justo en el menú donde el
   jugador lo buscaría. En pausa emite `pause_requested` **y**
   `mute_requested`; lo demás (apuntar, soltar, `R`) sigue bloqueado.
   - Actualiza `test_drop_controller.gd::test_while_paused_only_pause_is_emitted`
     (pasa a "solo pausa y silencio").
   - Actualiza `04` §4 (tabla de controles: `M` también en pausa) y `07` §6
     ("Pausada, `DropController` solo emite `pause_requested` y
     `mute_requested`").
2. **Fuga de la música al salir.** Al cerrar el juego, Godot avisa:

   ```text
   WARNING: 2 ObjectDB instances were leaked at exit
   ERROR: 1 resources still in use at exit
   Leaked instance: AudioStreamWAV / AudioStreamPlaybackWAV
   Resource still in use: res://assets/audio/bgm_workshop.wav
   Orphan StringName: Music
   ```

   Se reproduce con `godot --path . --scene res://game/main.tscn --quit-after 60`
   (con y sin Movie Maker). **Ya se ha comprobado** (no lo repitas):
   - sin `_music_player.play()` la fuga desaparece: la causa es la música;
   - un script mínimo que reproduce el mismo `bgm_workshop.wav` en bucle en un
     `AudioStreamPlayer` **no** tiene fuga: algo del proyecto retiene la
     reproducción;
   - **no** la arreglan: parar todos los reproductores en `_exit_tree` de
     `AudioDirector`, cambiar el bus de la música a `Master`, ni diferir el
     `play()`.

   Cómo seguir: biseca sobre una copia temporal de `main.tscn` (fuera del
   repo, o borrada antes del commit) quitando nodos (`GameUI`, `EffectsLayer`,
   `ScreenShake`, `DebugController`…) y desconectando señales de
   `AudioDirector` (`set_paused`, `_apply_music_volume`) hasta que desaparezca;
   `--verbose` muestra el detalle. Pistas: el `volume_db` que se cambia en
   caliente, `stream_paused`, el `Music` del `default_bus_layout.tres`.
   **Máximo una hora.** Si encuentras la causa en el proyecto, corrígela y
   añade el comando de arriba como comprobación manual del cierre en `07` §5.
   Si resulta ser un fallo del motor, deja un script mínimo que lo reproduzca
   en `docs/notas_motor.md` (nuevo; corto) y anótalo en "Desviaciones". No
   añadas *workarounds* opacos.
3. **Huérfanos en los tests.** GUT informa de nodos huérfanos en
   `test_piece_spawner`, `test_merge_system`, `test_board`,
   `test_danger_integration` y `test_session_integration`. Vienen del patrón
   `remove_child` + `queue_free` (regla de `02` §9: el recuento debe ser
   correcto en el mismo frame), y GUT cuenta los nodos antes de que termine el
   frame. **No cambies el patrón del código de juego.**
   - Primero comprueba cuándo cuenta GUT los huérfanos (después del test o
     después de `after_each`). Si es después de `after_each`, añade
     `await wait_process_frames(1)` al final de `after_each` en esos archivos
     (o en un helper común si el patrón se repite).
   - Si GUT cuenta antes de `after_each`, añade la espera al final de los tests
     afectados.
   - Criterio: la suite completa no informa de ningún huérfano. Si alguno
     resulta ser una fuga real (un nodo que nunca se libera), corrígelo en el
     código y descríbelo en el commit.

### Tests

- `test_drop_controller.gd`: en pausa, `toggle_mute` emite `mute_requested`;
  `drop`, `restart` y el movimiento del ratón siguen sin emitir nada.
- `test_session_integration.gd`: con el árbol en pausa, `mute_requested`
  alterna el mute del bus `Master` (restáuralo en `after_each`).

**Commit:** `fix(calidad): silencio en pausa, fuga de audio al salir y huérfanos en los tests`
(si la fuga resulta ser del motor, quita esa parte del mensaje).

---

## Fase 1 — Opciones persistentes

Volumen de música, volumen de efectos, silencio y pantalla completa, guardados
en el equipo del jugador. El silencio de `M` pasa a ser un ajuste más: se
guarda y la casilla de opciones lo refleja.

### Contrato

```gdscript
# game/settings_store.gd
class_name SettingsStore
extends RefCounted
## Ajustes del jugador persistidos con ConfigFile (`user://settings.cfg`).
## Sin autoload: lo crea Main. Mismo patrón que ScoreStore.

## Se emite tras cualquier cambio (también los que no se guardan aún).
signal changed

const DEFAULT_MUSIC_VOLUME: float = 0.8
const DEFAULT_SFX_VOLUME: float = 1.0

## `path` vacío → solo en memoria, nunca escribe a disco.
func _init(path: String) -> void
## Volúmenes lineales en [0, 1]; los setters acotan el valor.
func get_music_volume() -> float
func set_music_volume(volume: float) -> void
func get_sfx_volume() -> float
func set_sfx_volume(volume: float) -> void
func is_muted() -> bool
func set_muted(muted: bool) -> void
func is_fullscreen() -> bool
func set_fullscreen(fullscreen: bool) -> void
## Escribe a disco. Los setters NO guardan (un slider emite decenas de cambios):
## guarda Main al cerrar la vista de opciones y al alternar el silencio con M.
func save() -> void

# ui/audio_director.gd (añadido; sustituye a toggle_mute, que se elimina)
## Aplica los volúmenes a los buses Music y SFX (volumen 0 → bus en mute) y el
## silencio al bus Master.
func apply_settings(settings: SettingsStore) -> void

# ui/display_director.gd (nuevo; Presentación. En la fase 3 gestiona también
# la orientación y la disposición de la pantalla)
class_name DisplayDirector
extends Node
## Ventana y pantalla: pantalla completa (y, desde la fase 3, el diseño
## adaptable). No conoce la simulación.
## `allow_fullscreen` false → ignora la petición (web móvil, tests).
func setup(allow_fullscreen: bool) -> void
## Cambia el modo de ventana solo si difiere del actual.
func apply_settings(settings: SettingsStore) -> void

# ui/game_ui.gd (añadidos)
signal options_opened
## Intenciones de la vista de opciones (Main las traslada a SettingsStore).
signal music_volume_requested(volume: float)
signal sfx_volume_requested(volume: float)
signal muted_requested(muted: bool)
signal fullscreen_requested(fullscreen: bool)
signal options_closed
## Oculta la casilla de pantalla completa si es false.
@export var allow_fullscreen: bool = true
## Sincroniza los controles con los ajustes SIN emitir señales
## (`set_value_no_signal`, `set_pressed_no_signal`).
func show_settings(settings: SettingsStore) -> void

# ui/drop_controller.gd (añadido)
signal fullscreen_requested        # acción `toggle_fullscreen` (F11)

# game/main.gd (añadidos)
## Ruta de los ajustes. Vacía → solo en memoria (la usan los tests).
@export var settings_path: String = "user://settings.cfg"
func get_display_director() -> DisplayDirector
```

### Pasos

1. **`SettingsStore`.** Sección `[settings]`, claves `music_volume`,
   `sfx_volume`, `muted`, `fullscreen`. Un archivo ausente o corrupto, o un
   valor de tipo inesperado, equivale a los valores por defecto (nunca un
   error); copia el criterio de `ScoreStore._load`. Archivo propio
   (`user://settings.cfg`), separado de los récords.
2. **Audio.** `apply_settings` pone `AudioServer.set_bus_volume_db` de `Music` y
   `SFX` con `linear_to_db(volume)`, y `set_bus_mute(bus, volume <= 0.0)` (con 0,
   `linear_to_db` da `-inf`). El silencio va al bus `Master` (índice 0). La
   atenuación de la música en pausa y fin de partida sigue en el
   `volume_db` del reproductor (`MUSIC_VOLUME_DB`, `MUSIC_DUCKED_DB`): ajuste
   del jugador (bus) y atenuación del juego (reproductor) se multiplican sin
   pisarse. Elimina `toggle_mute` y sus tests; los sustituyen los de
   `apply_settings`.
3. **Pantalla.** `DisplayDirector.apply_settings` usa
   `DisplayServer.window_set_mode(WINDOW_MODE_FULLSCREEN | WINDOW_MODE_WINDOWED)`
   solo si `allow_fullscreen` y el modo actual es distinto. Nueva acción
   `toggle_fullscreen` (F11) en el InputMap; `DropController` emite
   `fullscreen_requested` (también en pausa, como el silencio).
4. **Vista de opciones** (`Root/OptionsView`, `PanelContainer` con el
   pergamino del tema, como las demás):
   - "Música" (`HSlider` 0–1, paso 0,05), "Efectos" (ídem), "Silencio"
     (`CheckBox`), "Pantalla completa" (`CheckBox`, oculto si
     `allow_fullscreen` es false) y "Volver";
   - se abre con un botón "Opciones" en la vista de título y en la de pausa;
     mientras está abierta, la vista que la abrió se oculta y al pulsar
     "Volver" reaparece;
   - **`mouse_filter = STOP`** en `OptionsView`: con la partida en `READY`, un
     clic en una zona vacía del panel no debe llegar a `DropController` y
     empezar la partida (las demás vistas son `IGNORE` a propósito: el clic en
     la de título sí empieza);
   - al soltar el slider de efectos (`drag_ended`), suena el clic de la
     interfaz para oír el volumen nuevo.
5. **Cableado en `Main`** (solo conexiones; nada de lógica):
   - `_settings = SettingsStore.new(settings_path)`; al componer, y en cada
     `_settings.changed`: `_audio_director.apply_settings(_settings)`,
     `_display_director.apply_settings(_settings)` y
     `_ui.show_settings(_settings)`;
   - señales de la vista → setters de `_settings`; `options_closed` →
     `_settings.save()`;
   - `DropController.mute_requested` → `_settings.set_muted(not _settings.is_muted())`
     y `_settings.save()`; `fullscreen_requested` → lo mismo con pantalla
     completa;
   - `allow_fullscreen` = `not OS.has_feature("web") and not OS.has_feature("mobile")`
     por ahora (la fase 5 lo afina para web de escritorio). Se pasa a
     `DisplayDirector.setup` y a `GameUI.allow_fullscreen`.
6. Documenta en `07` §5 (buses y ajustes del jugador frente a la atenuación del
   juego) y §6 (vista de opciones), y en `04` §4 (F11). Añade `SettingsStore` y
   `DisplayDirector` a la tabla de componentes de `02` §4 (una fila cada uno,
   con una línea de descripción).

### Tests

- `test_settings_store.gd` (nuevo, ruta `user://test_settings.cfg` borrada en
  `after_each`): valores por defecto; los setters acotan a [0, 1]; `save` y
  otra instancia con la misma ruta los lee; sin `save` no se escribe; archivo
  corrupto y tipo inesperado → valores por defecto; ruta vacía nunca toca el
  disco; `changed` se emite en cada setter.
- `test_audio_director.gd`: `apply_settings` pone el volumen de los buses
  `Music` y `SFX`; volumen 0 → bus en mute; `muted` → `Master` en mute.
  Restaura los buses en `after_each`.
- `test_game_ui.gd`: "Opciones" desde título y desde pausa abre la vista y
  oculta la de origen; "Volver" emite `options_closed` y la restaura; mover un
  slider emite su señal; `show_settings` actualiza los controles **sin**
  emitir señales; con `allow_fullscreen = false` la casilla no se ve;
  `OptionsView.mouse_filter == MOUSE_FILTER_STOP`.
- `test_session_integration.gd`: `mute_requested` alterna
  `SettingsStore.is_muted()` y el mute del bus `Master`, también en pausa.

**Commit:** `feat(opciones): volumen de música y efectos, silencio y pantalla completa persistentes`

---

## Fase 2 — Distribución de escritorio

### Contrato

```gdscript
# ui/game_ui.gd (añadidos)
signal quit_requested
## Oculta los botones "Salir" (web).
@export var allow_quit: bool = true
## Texto de versión (`application/config/version`), en la vista de título.
func set_version(version: String) -> void
```

### Pasos

1. **Versión.** `application/config/version="0.3.0"` en `project.godot`.
   `Main` la lee (`ProjectSettings.get_setting`) y llama a `_ui.set_version`;
   la vista de título la muestra pequeña ("v0.3.0") en su esquina inferior.
2. **Icono de la aplicación.**
   - Nueva entrada en `tools/asset_spec.gd`: `assets/ui/app_icon.png`,
     512×512. El generador crea su placeholder (silueta de un alambique o
     matraz sobre fondo redondeado, con los colores del tema) y su plantilla
     en `docs/plantillas/` con la zona segura (círculo de 410 px, como los
     materiales). Ejecuta el generador **sin** `--force`.
   - `application/config/icon="res://assets/ui/app_icon.png"`. Borra
     `icon.svg` y su `.import` (es el logo de Godot) tras comprobar con `grep`
     que nada más lo referencia.
   - Añade la fila a la tabla de `07` §7.3 (placeholder) y al Anexo A de este
     plan (abajo).
   - El icono **nativo** de Windows (`.ico` incrustado en el `.exe`) necesita
     `rcedit` configurado en el editor: queda fuera (ver "Decisiones
     abiertas"). La ventana sí usa el icono del proyecto.
3. **Salir.** Botón "Salir" en la vista de título y en la de pausa, oculto si
   `allow_quit` es false. `GameUI` emite `quit_requested` → `Main` llama a
   `_settings.save()` y `get_tree().quit()`. `allow_quit` =
   `not OS.has_feature("web")`.
4. **Créditos.** Botón "Créditos" en la vista de título → `Root/CreditsView`
   (pergamino, `mouse_filter = STOP`, "Volver"): nombre del juego, versión,
   autoría, y un `ScrollContainer` con:
   - "Hecho con Godot Engine" y `Engine.get_license_text()` (la licencia MIT
     de Godot obliga a incluir el aviso en las copias distribuidas);
   - la lista de componentes de terceros de `Engine.get_copyright_info()`
     (solo los nombres);
   - un hueco para la licencia OFL de la fuente, que se rellena al integrarla.
   La autoría y el texto exacto son decisión del usuario (ver "Decisiones
   abiertas"); deja un texto provisional claro ("Autor: por definir").
5. **Presets de exportación.** Quita `export_presets.cfg` de `.gitignore`: los
   presets de escritorio y web no contienen secretos (los de Android sí, con el
   *keystore*; nunca se suben). Crea `export_presets.cfg` a mano con estos dos
   presets (Godot completa al cargar las opciones que falten; ábrelo con
   `godot --headless --path . --export-release "Linux" …` para comprobarlo):

   ```ini
   [preset.0]
   name="Linux"
   platform="Linux"
   runnable=true
   export_filter="all_resources"
   include_filter=""
   exclude_filter="tests/*, tools/*, addons/gut/*"
   export_path="dist/linux/el_alquimista_pobre.x86_64"

   [preset.0.options]
   binary_format/embed_pck=true
   binary_format/architecture="x86_64"

   [preset.1]
   name="Windows"
   platform="Windows Desktop"
   runnable=true
   export_filter="all_resources"
   include_filter=""
   exclude_filter="tests/*, tools/*, addons/gut/*"
   export_path="dist/windows/el_alquimista_pobre.exe"

   [preset.1.options]
   binary_format/embed_pck=true
   binary_format/architecture="x86_64"
   application/modify_resources=false
   codesign/enable=false
   ```

   `application/modify_resources=false` evita depender de `rcedit`.
6. **Script de exportación** `tools/export_all.sh` (bash, con `set -euo pipefail`):
   reimporta, ejecuta la suite de GUT (aborta si falla), crea `dist/<plataforma>/`
   y exporta cada preset con `--export-release`. Después, **prueba de humo**:
   ejecuta el binario de Linux con `--headless --quit-after 120` y falla si la
   salida contiene `ERROR` o `SCRIPT ERROR` (ignora la fuga de la fase 0 solo si
   quedó anotada como fallo del motor). En la fase 5 se le añade la web.
7. **Comprobaciones manuales del build de release** (anótalas en el commit):
   - arranca con la pantalla de título y se juega una partida completa;
   - F1–F4 y F12 no hacen nada (`DebugController` solo actúa en builds de
     depuración);
   - el récord y los ajustes se guardan en `user://` del build exportado
     (`~/.local/share/godot/app_userdata/El Alquimista Pobre/`);
   - el tamaño de los binarios (anótalo en `07` §7 como referencia).
   Si `wine` está instalado, arranca también el `.exe`; si no, dilo en el
   commit en lugar de darlo por probado.
8. README: sección "Builds" con `tools/export_all.sh`, las rutas de `dist/` y
   dónde guarda los datos el juego.

### Tests

- `test_asset_spec.gd` ya cubre el icono al estar en la especificación; añade
  `test_project_icon_is_the_app_icon` (lee `application/config/icon`).
- `test_game_ui.gd`: con `allow_quit = false` no se ve ningún "Salir"; "Salir"
  emite `quit_requested`; "Créditos" abre la vista y su texto contiene la
  primera línea de `Engine.get_license_text()`; `set_version` se ve en el
  título; `CreditsView.mouse_filter == MOUSE_FILTER_STOP`.
- El cierre no se prueba con GUT (`quit()` terminaría la propia suite). `Main`
  conecta `quit_requested` a un callback de dos líneas (`_settings.save()` y
  `get_tree().quit()`); el guardado ya lo cubren los tests de la fase 1.

**Commits:**
- `feat(distribución): versión, icono, salir y créditos`
- `build(export): presets de Linux y Windows y script de exportación`

---

## Fase 3 — Diseño adaptable (horizontal y vertical)

Hoy la pantalla está pensada para 1280×720 con `stretch/aspect = "expand"`. En
un móvil en vertical (p. ej. 390×844) la escala se fija por el ancho y el
recipiente ocuparía un tercio de la pantalla. Esta fase cambia la **resolución
base** según la orientación y recoloca el HUD.

### Contrato

```gdscript
# ui/screen_layout.gd (nuevo; Presentación; puro: sin nodos ni ventana)
class_name ScreenLayout
extends RefCounted
## Dónde va cada elemento de la pantalla para un tamaño visible dado.
## Coordenadas de pantalla (unidades de la resolución base, no píxeles físicos).

enum Orientation { LANDSCAPE, PORTRAIT }

const LANDSCAPE_BASE := Vector2i(1280, 720)
const PORTRAIT_BASE := Vector2i(576, 1024)

var orientation: Orientation
## Origen del tablero (esquina superior izquierda del interior del recipiente).
var board_origin: Vector2
var score_rect: Rect2
var next_rect: Rect2
var legend_rect: Rect2
var legend_columns: int
## Botón de pausa en pantalla (fase 4).
var pause_button_rect: Rect2

## PORTRAIT si el alto supera al ancho; tamaño nulo o cuadrado → LANDSCAPE.
static func orientation_for(window_size: Vector2i) -> Orientation
static func base_size(orientation: Orientation) -> Vector2i
static func compute(visible_size: Vector2, orientation: Orientation,
		config: GameConfig) -> ScreenLayout

# ui/display_director.gd (añadidos)
signal layout_changed(layout: ScreenLayout)
## Además de `allow_fullscreen`, recibe la configuración para calcular la
## disposición. Sustituye a la firma de la fase 1.
func setup(allow_fullscreen: bool, config: GameConfig) -> void
## Última disposición calculada (para los tests y para Main al componer).
func get_layout() -> ScreenLayout

# ui/game_ui.gd (añadido)
## Recoloca puntuación, PRÓXIMO, leyenda y botón de pausa.
func apply_layout(layout: ScreenLayout) -> void
```

### Pasos

1. **Disposición horizontal** (la de hoy, ahora calculada): base 1280×720;
   `board_origin = ((ancho_visible − container_width) / 2, 80)` (lo que hace hoy
   `Main._update_world_position`); puntuación a la izquierda del recipiente y
   PRÓXIMO + leyenda (1 columna) a la derecha, con los márgenes actuales de
   `game_ui.tscn` (32 px). El título "El Alquimista Pobre" del HUD se ve.
2. **Disposición vertical**, base 576×1024 (el recipiente de 504 px de ancho
   exterior ocupa el 87 %):
   - franja superior (y 16–140): puntuación y récord a la izquierda, PRÓXIMO a
     la derecha; sin el título del HUD (ya está en la vista de título);
   - recipiente centrado en horizontal con `board_origin.y = 200`: deja sitio
     para la pieza en `spawn_y` y el artefacto del alquimista, que se dibujan
     hasta ~70 px por encima del interior;
   - leyenda debajo del recipiente, en **2 columnas** (4 filas);
   - si el alto visible supera 1024 (móviles alargados), todo el bloque se
     centra en vertical: se suma `(alto_visible − 1024) / 2` a cada `y`.
   Comprueba con números que nada se solapa con `container_height = 600` y
   `wall_thickness = 32`; si no cabe, ajusta las constantes de `ScreenLayout`,
   no los datos del juego.
3. **`ScreenLayout.compute` es pura.** Ningún nodo, ninguna consulta a la
   ventana: recibe el tamaño visible y devuelve rectángulos. Así se prueba con
   cualquier tamaño de pantalla sin abrir ventanas.
4. **`DisplayDirector`** escucha `get_tree().root.size_changed`:
   1. calcula la orientación con `get_window().size` (píxeles físicos);
   2. si su base difiere de `get_window().content_scale_size`, la asigna (esto
      vuelve a emitir `size_changed`; la segunda vez la base ya coincide y no se
      repite: compruébalo con un test o un contador);
   3. calcula `ScreenLayout.compute(get_viewport().get_visible_rect().size, …)`
      y emite `layout_changed`.
   Al llamar a `setup`, hace lo mismo una vez para que `Main` tenga la
   disposición inicial.
5. **`Main`**: elimina `_update_world_position` y su conexión a
   `size_changed`; conecta `layout_changed` a un callback que hace
   `_world.position = layout.board_origin` y `_ui.apply_layout(layout)`.
   `DropSystem.request_aim_global` ya convierte a coordenadas de tablero con
   `to_local`, así que el apuntado con ratón no cambia.
6. **`game_ui.tscn`**: separa `LeftPanel`/`RightPanel` en `ScorePanel`
   (título, puntuación, récord), `NextPanel` (etiqueta + icono) y `LegendPanel`
   (un `GridContainer`; `columns` = `legend_columns`). `apply_layout` asigna
   `position` y `size` de cada panel desde los rectángulos (sin anclas). Las
   vistas centradas (título, pausa, opciones, créditos, fin) siguen ancladas al
   centro y caben en 576 de ancho (mínimo 320).
7. **Fondo del taller**: comprueba que `Background/Workshop` cubre la pantalla
   en ambas orientaciones (`stretch_mode = KEEP_ASPECT_COVERED`, anclado a
   toda la pantalla); en vertical se recorta por los lados, como se espera.
8. **Capturas** (Movie Maker, `--resolution`): 1280×720, 1920×1080, 1024×768
   (tableta horizontal), 576×1024, 390×844 (móvil) y 412×915 (móvil alargado).
   Revisa: nada se solapa, la leyenda se lee, el recipiente es lo más grande.
   En escritorio también se puede redimensionar la ventana a vertical y ver el
   cambio en directo.
9. Documenta en `07` §2 y §6 las dos disposiciones (una tabla con los
   rectángulos y la regla de orientación). Añade `ScreenLayout` a `02` §4.

### Tests

- `test_screen_layout.gd` (nuevo, unitario, sin ventana):
  - `orientation_for`: 1280×720 y 800×800 → `LANDSCAPE`; 390×844 → `PORTRAIT`;
    `Vector2i.ZERO` → `LANDSCAPE`;
  - para cada orientación y varios tamaños visibles (horizontal: 1280×720,
    1280×960, 1706×720; vertical: 576×1024, 576×1250, 640×1024):
    - todos los rectángulos están dentro del área visible;
    - ninguno se cruza con el rectángulo exterior del recipiente (interior más
      paredes, y 80 px por encima del interior para la pieza y el artefacto);
    - los paneles no se cruzan entre sí;
    - `legend_rect` tiene alto para `ceil(8 / legend_columns)` filas de 30 px
      (icono de 24 + separación de 6);
    - el recipiente queda centrado en horizontal.
- `test_game_ui.gd`: `apply_layout` coloca cada panel en su rectángulo; en
  vertical la leyenda tiene 2 columnas y el título del HUD no se ve.
- `test_session_integration.gd`: emitir `layout_changed` con una disposición
  vertical mueve `World` a `board_origin`; `get_display_director().get_layout()`
  no es `null` tras `_ready`.

**Commit:** `feat(pantalla): diseño adaptable horizontal y vertical`

---

## Fase 4 — Control táctil

### Hechos del motor (comprobados; no hace falta repetirlos)

- `input_devices/pointing/emulate_mouse_from_touch` está activo por defecto:
  cada toque genera además un evento de ratón **emulado**, con
  `device == InputEvent.DEVICE_ID_EMULATION` (−1). Un ratón real tiene
  `device` 0.
- Un `Button` consume **tanto** el `InputEventScreenTouch` crudo como el clic
  emulado: un toque sobre un botón nunca llega a `_unhandled_input`. Los paneles
  con `mouse_filter = IGNORE` sí lo dejan pasar.
- Hoy un toque suelta la pieza **al apoyar el dedo** (el clic emulado dispara
  `drop`), sin dejar apuntar.

### Reglas nuevas (`04` §4)

| Gesto | Efecto |
| ----- | ------ |
| Apoyar un dedo | Apunta a la X del dedo |
| Arrastrar | La posición sigue al dedo |
| Levantar el dedo | Suelta el material actual |
| Toque cancelado por el sistema (`canceled`) | No suelta |
| Segundo dedo mientras el primero está apoyado | Se ignora |
| Botón de pausa en pantalla | Pausa (solo en `PLAYING`) |

Con la partida en `READY`, levantar el dedo empieza la partida sin soltar
(el camino de siempre: `drop_requested` → `Main` → `_state.start()`).

### Contrato

```gdscript
# ui/drop_controller.gd (sin señales nuevas: el táctil emite las mismas
# intenciones que el ratón)
## Índice del dedo que apunta; -1 si ninguno.
var _touch_index: int = -1

# ui/game_ui.gd (añadidos)
signal pause_requested           # botón de pausa del HUD
## Textos para pantalla táctil ("Toca para empezar", "Reiniciar" sin "(R)").
@export var touch_hints: bool = false
```

### Pasos

1. **`DropController`**:
   - ignora los eventos de ratón con `device == InputEvent.DEVICE_ID_EMULATION`
     (movimiento **y** la acción `drop`): el táctil se gestiona con sus propios
     eventos. Compruébalo **antes** de `is_action_pressed("drop")`, que acepta
     cualquier dispositivo;
   - `InputEventScreenTouch` pulsado con `_touch_index == -1` → guarda el
     índice y emite `aim_requested(position.x)`;
   - `InputEventScreenDrag` del mismo índice → `aim_requested(position.x)`;
   - `InputEventScreenTouch` soltado del mismo índice → si no es `canceled`,
     `drop_requested`; en cualquier caso `_touch_index = -1`;
   - en pausa: `_touch_index = -1` y no emite nada (un dedo apoyado al pausar
     no debe soltar al reanudar).
   Las posiciones de los eventos ya llegan transformadas al viewport (como las
   del ratón); `request_aim_global` las convierte al tablero.
2. **Botón de pausa** en el HUD (`Root/PauseButton`, "❚❚" o el texto "Pausa"
   si la fuente no tiene el glifo), colocado en `pause_button_rect`; visible solo
   en `PLAYING`. Emite `GameUI.pause_requested` → `Main` lo conecta al mismo
   `_on_pause_requested` que la tecla. Se ve también en escritorio (sirve con
   ratón).
3. **Tamaño táctil.** En vertical, los botones de las vistas miden al menos
   64 unidades de alto (≈ 44 px CSS en un móvil de 390 de ancho). Hazlo con una
   variación de tema (`TouchButton`) que `apply_layout` asigna en vertical, no
   con overrides sueltos.
4. **Textos.** `Main` pone `touch_hints = DisplayServer.is_touchscreen_available()`.
   Con `touch_hints`: "Toca para empezar" en el título y "Reiniciar" en las
   vistas de fin.
5. **Prueba en escritorio.** No hay forma limpia de emular el táctil con el
   ratón sin duplicar eventos (`emulate_touch_from_mouse` generaría ambos). La
   lógica se prueba con eventos sintéticos en los tests; el dispositivo real,
   en la fase 5.
6. Actualiza `04` §4 (tabla de gestos) y `07` §6 (botón de pausa, textos
   táctiles, tamaño de botones).

### Tests

- `test_drop_controller.gd` (llamando a `_unhandled_input` con eventos
  sintéticos, como ya hace):
  - clic y movimiento con `device = DEVICE_ID_EMULATION` no emiten nada;
  - con `device = 0`, el ratón sigue funcionando como antes;
  - apoyar → `aim_requested(x)`; arrastrar → `aim_requested(x2)`; levantar →
    `drop_requested` una sola vez;
  - un segundo dedo (otro índice) no apunta ni suelta;
  - levantar con `canceled = true` no suelta;
  - pausar con un dedo apoyado y despausar: levantar no suelta.
- `test_game_ui.gd`: el botón de pausa solo se ve en `PLAYING` y emite
  `pause_requested`; con `touch_hints` cambian los textos.
- `test_session_integration.gd`: en `READY`, apoyar y levantar empieza la
  partida sin crear piezas; un segundo toque completo crea exactamente una
  pieza en la X del dedo (convertida a tablero, acotada por el radio).

**Commit:** `feat(entrada): control táctil con arrastrar y soltar, y botón de pausa`

---

## Fase 5 — Exportación web

### Pasos

1. **Preset "Web"** en `export_presets.cfg`:

   ```ini
   [preset.2]
   name="Web"
   platform="Web"
   runnable=true
   export_filter="all_resources"
   include_filter=""
   exclude_filter="tests/*, tools/*, addons/gut/*"
   export_path="dist/web/index.html"

   [preset.2.options]
   variant/thread_support=false
   html/canvas_resize_policy=2
   html/focus_canvas_on_start=true
   progressive_web_app/enabled=false
   ```

   **Sin hilos** (`thread_support=false`): no necesita las cabeceras
   COOP/COEP de `SharedArrayBuffer`, así que funciona en cualquier hosting
   estático e itch.io. El renderer ya es `gl_compatibility` (el único que
   soporta la web).
2. **Ajustes de plataforma en `Main`** (afina los de las fases 1 y 2):
   - `allow_quit = not OS.has_feature("web")`;
   - `allow_fullscreen`: en web solo en navegadores de escritorio. Comprueba en
     la documentación de 4.7 los *feature tags* `web_android` / `web_ios`; si
     no existen, usa `not DisplayServer.is_touchscreen_available()`. En web, el
     cambio de modo funciona porque se hace dentro del clic en la casilla (un
     gesto del usuario).
3. **Audio.** Los navegadores no dejan sonar nada hasta el primer gesto del
   usuario; Godot reanuda el audio en la primera entrada. La pantalla de
   título garantiza ese gesto. Comprueba en el navegador que la música empieza
   al primer clic o toque; si no, haz que `AudioDirector` arranque la música
   la primera vez que el estado pase a `PLAYING` (y anótalo).
4. **Persistencia.** En web, `user://` vive en IndexedDB. Comprueba
   `OS.is_userfs_persistent()` en una partida de prueba (imprímelo solo en
   builds de depuración). Si es `false` (navegación privada), récord y ajustes
   funcionan en memoria sin errores. Comprueba que el récord sobrevive a
   recargar la página.
5. **Pausa al cambiar de pestaña.** `NOTIFICATION_APPLICATION_FOCUS_OUT` debe
   llegar al ocultar la pestaña; compruébalo. Si no llega, anótalo (no lo
   sustituyas por JavaScript).
6. **`tools/export_all.sh`**: añade el preset Web y un `zip` de `dist/web/`
   (`dist/el_alquimista_pobre_web.zip`, listo para itch.io).
7. **Prueba local**: `python3 -m http.server 8000 -d dist/web` y abrir
   `http://localhost:8000` en Chrome y Firefox. Para un móvil en la misma red:
   `http://<IP-del-equipo>:8000`. Si el navegador del móvil exige contexto
   seguro, usa un borrador privado en itch.io (paso 9) en lugar de inventar
   certificados.
8. **Lista de comprobación en dispositivo** (rellénala en `07` §8, nueva, con
   navegador y dispositivo; lo no probado se marca "sin probar", no se da por
   bueno):
   - carga y pantalla de título; música tras el primer toque;
   - vertical y horizontal, y girar el móvil en mitad de la partida;
   - arrastrar y soltar; botón de pausa; opciones (volúmenes, silencio);
   - récord tras recargar la página;
   - pausa al cambiar de pestaña;
   - fluidez con el recipiente casi lleno (subjetiva; anota el modelo).
9. **itch.io** (solo instrucciones en el README; publicar es decisión del
   usuario): proyecto HTML, subir el zip, "This file will be played in the
   browser", tamaño de ventana 1280×720, "Mobile friendly" con orientación
   por defecto, botón de pantalla completa activado, **sin** "SharedArrayBuffer
   support".
10. README: añade "Web" a la sección "Builds".

### Tests

- La web no se prueba con GUT. Añade a `test_session_integration.gd` el caso de
  plataforma que sí es lógica: con `allow_quit = false` y
  `allow_fullscreen = false` inyectados, no hay botón "Salir" ni casilla de
  pantalla completa visibles.

**Commit:** `build(web): exportación web sin hilos y ajustes de plataforma`

---

## Fase 6 — Balance con partidas humanas (bloqueante)

**Precondición:** `docs/notas_playtest.md` tiene partidas humanas anotadas por el
usuario, al menos 3 por estrategia (ahora también pueden ser en el móvil). **Si
el apartado "Partidas humanas" sigue vacío, detente aquí** y díselo al usuario:
no inventes sensaciones ni resultados, y no cambies ningún valor.

### Pasos

1. Lee las notas y la simulación automática del mismo archivo. Resume por
   estrategia: duración, victorias, momentos frustrantes repetidos.
2. Propón cambios **solo de datos** (`GameConfig`, `bounce`/`friction` de
   `piece.tscn`, pesos de los presets, estrategia por defecto) en una tabla:
   valor actual, valor propuesto, la nota humana que lo motiva y el efecto
   esperado. **Espera la aprobación del usuario** antes de aplicar nada.
3. Aplica los aprobados. Para cada uno: ejecuta
   `tools/balance_sim.gd -- --games=20` antes y después, y pega ambos
   resúmenes en `notas_playtest.md` §"Cambios de balance aplicados", con el
   motivo.
4. Actualiza `03_data_design.md` (valores y tabla de `GameConfig`) y los tests
   que fijen esos valores (`test_real_data.gd`).
5. Ningún cambio de código en esta fase. Si las notas piden una mecánica nueva
   (p. ej. bonificación por cascada), anótala como propuesta para la siguiente
   iteración en lugar de implementarla.

**Commit:** `balance(config): <qué cambia> según las partidas de prueba`

---

## Decisiones abiertas (para el usuario)

| Decisión | Recomendación por defecto | Cuándo decidir |
| -------- | ------------------------- | -------------- |
| Autoría y texto de créditos | "Francisco Beltrán" y el texto que prefieras; el agente deja "por definir" | Fase 2 |
| Número de versión inicial | `0.3.0` (iteración 3) | Fase 2 |
| Icono nativo del `.exe` (necesita `rcedit` en el editor) | Más adelante; la ventana ya usa el icono | Tras la fase 2 |
| Resolución base vertical | 576×1024 | Fase 3, tras ver las capturas |
| Soltar al levantar el dedo o al tocar | Al levantar (permite apuntar), como Suika en móvil | Fase 4 |
| Vibración en fusiones altas (`Input.vibrate_handheld`) | No en esta iteración (soporte web irregular) | Siguiente iteración |
| Publicar en itch.io | Borrador privado primero para probar en el móvil | Fase 5 |
| Exportación nativa Android/iOS | Fuera; la web cubre el móvil | Siguiente iteración |

---

## Anexo A — Assets nuevos

Se añaden a la especificación de `06` Anexo A (`tools/asset_spec.gd` es la fuente
única) y siguen el mismo procedimiento de integración (`07` §7.1).

| Archivo | Tamaño | Descripción |
| ------- | ------ | ----------- |
| `assets/ui/app_icon.png` | 512×512 | Icono de la aplicación (ventana, favicon web). Un objeto reconocible a 32 px (alambique o matraz con un brillo dorado); contenido dentro del círculo de 410 px, fondo transparente o redondeado. |

---

## Desviaciones

*(El agente implementador anota aquí cualquier cambio respecto a esta guía,
con su motivo y la fase en que ocurrió.)*
