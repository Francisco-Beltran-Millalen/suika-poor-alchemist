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
9. **Nada fuera del proyecto.** No instales paquetes ni ejecutes programas
   que escriban fuera del repositorio, `dist/` o un directorio temporal (wine,
   navegadores, servidores web, emuladores…). Lo que requiera esas
   herramientas (arrancar el `.exe`, probar en el navegador o en el móvil) es
   una **comprobación manual del usuario**: déjala escrita como lista en `07`,
   con "sin probar" en cada punto, y no la des por hecha.

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
  puedan simular cualquier plataforma. **Los *flags* se pasan con un método**
  (`GameUI.set_platform`, `DisplayDirector.setup`), nunca solo como
  `@export` leído en `_ready`: `Main` los calcula cuando `GameUI` ya está
  lista, y un valor leído solo en `_ready` no tendría efecto en el juego
  aunque los tests (que lo fijan antes de `add_child`) pasen.
- **Vistas modales** (opciones, créditos): son un `Control` a **pantalla
  completa** con `mouse_filter = STOP` que contiene el panel centrado. Un
  `STOP` solo en el panel deja pasar los clics de fuera, que llegarían a
  `DropController` (en `READY` empezarían la partida). Verificado: un
  `Control` a pantalla completa con `STOP` consume el toque crudo y el clic
  emulado.
- **Ratón en los tests:** un `InputEventMouseButton.new()` trae
  `device = InputEvent.DEVICE_ID_MOUSE` (32); el clic emulado desde un toque
  trae `DEVICE_ID_EMULATION` (−1). Usa esas constantes, no números.
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
   (con y sin Movie Maker) y **también en el binario exportado** (Linux y
   Windows). Lo comprobado hasta ahora:
   - sin `_music_player.play()` la fuga desaparece: la causa es la música;
   - **no** la arreglan: parar los reproductores en `_exit_tree` de
     `AudioDirector`, cambiar el bus de la música a `Master`, ni diferir el
     `play()`;
   - parar la música (o liberar el reproductor) **unos frames antes** de
     `quit()` sí la evita; pararla en el mismo frame del `quit()`, no;
   - resultado contradictorio: un script mínimo que reproduce
     `bgm_workshop.wav` y sale con `--quit-after 60` dio fuga en un proyecto
     nuevo y vacío, pero **no** dentro de este proyecto. No está claro si es
     del motor o del proyecto.

   Cómo seguir (**máximo una hora**): repite la reproducción mínima en ambos
   sitios para aclarar la contradicción (`--verbose` da el detalle).
   - Si es del motor: deja el script mínimo en `docs/notas_motor.md` (nuevo;
     corto) y anótalo en "Desviaciones". La salida limpia del juego se
     resuelve en la fase 2 (paso 3): "Salir" para la música y sale unos
     frames después.
   - Si es del proyecto: biseca sobre una copia temporal de `main.tscn`
     (fuera del repo, o borrada antes del commit) quitando nodos y
     desconectando señales de `AudioDirector` hasta que desaparezca, y
     corrígela.
   No añadas *workarounds* opacos. Añade el comando de arriba como
   comprobación del cierre en `07` §5.
3. **Huérfanos en los tests.** GUT informa de nodos huérfanos en
   `test_piece_spawner`, `test_merge_system`, `test_board`,
   `test_danger_integration` y `test_session_integration`. Vienen del patrón
   `remove_child` + `queue_free` (regla de `02` §9: el recuento debe ser
   correcto en el mismo frame), y GUT cuenta los nodos antes de que termine el
   frame. **No cambies el patrón del código de juego.**
   - **Verificado:** GUT 9.6 cuenta los huérfanos después de `after_each` y
     de liberar los `autofree` (`addons/gut/gut.gd`, ~l. 629–639), y
     `await wait_process_frames(1)` al final de `after_each` los elimina en
     `test_piece_spawner`, `test_merge_system` y `test_board`. Esos tres
     archivos no tienen `after_each`: créalo. Aplica lo mismo a
     `test_danger_integration` y `test_session_integration` (sin verificar).
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

## Se emite cuando un setter cambia el valor (no si es el mismo), también
## antes de guardar.
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
## `config` no se usa hasta la fase 3 (diseño adaptable); se recibe ya para no
## cambiar la firma después.
func setup(allow_fullscreen: bool, config: GameConfig) -> void
## Cambia el modo de ventana solo si difiere del actual.
func apply_settings(settings: SettingsStore) -> void

# ui/options_view.gd + ui/options_view.tscn (nuevo; escena propia para que
# game_ui.gd no pase de 400 líneas)
class_name OptionsView
extends Control
## Vista modal de opciones: Control a pantalla completa (STOP) con el panel
## de pergamino centrado. Solo emite intenciones.
signal music_volume_requested(volume: float)
signal sfx_volume_requested(volume: float)
signal muted_requested(muted: bool)
signal fullscreen_requested(fullscreen: bool)
## Se emite al soltar el slider de efectos (para oír el volumen nuevo).
signal sfx_preview_requested
signal closed
## Sincroniza los controles con los ajustes SIN emitir señales
## (`set_value_no_signal`, `set_pressed_no_signal`).
func show_settings(settings: SettingsStore) -> void
## Oculta la casilla de pantalla completa si es false.
func set_allow_fullscreen(allow: bool) -> void

# ui/game_ui.gd (añadidos; instancia OptionsView como `Root/OptionsView` y
# reenvía sus señales con el mismo nombre)
signal music_volume_requested(volume: float)
signal sfx_volume_requested(volume: float)
signal muted_requested(muted: bool)
signal fullscreen_requested(fullscreen: bool)
signal options_closed
## Flags de plataforma; aplica la visibilidad al momento (ver Convenciones).
## Las fases 2 y 4 usan `allow_quit` y `touch_hints`; en la fase 1 solo
## `allow_fullscreen` tiene efecto.
func set_platform(allow_quit: bool, allow_fullscreen: bool, touch_hints: bool) -> void
func show_settings(settings: SettingsStore) -> void

# ui/drop_controller.gd (añadido)
signal fullscreen_requested        # acción `toggle_fullscreen` (F11)

# game/main.gd (añadidos)
## Ruta de los ajustes. Vacía → solo en memoria (la usan los tests).
@export var settings_path: String = "user://settings.cfg"
func get_display_director() -> DisplayDirector
func get_settings() -> SettingsStore
```

### Pasos

1. **`SettingsStore`.** Sección `[settings]`, claves `music_volume`,
   `sfx_volume`, `muted`, `fullscreen`. Un archivo ausente o corrupto, o un
   valor de tipo inesperado, equivale a los valores por defecto (nunca un
   error); copia el criterio de `ScoreStore._load`. Archivo propio
   (`user://settings.cfg`), separado de los récords. Los setters emiten
   `changed` solo si el valor cambia.
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
   `fullscreen_requested` (también en pausa, como el silencio). Con
   `allow_fullscreen` false, `Main` ignora F11 sin tocar el ajuste (no se
   guarda `fullscreen = true` en una plataforma que no puede aplicarlo).
4. **Vista de opciones** (`ui/options_view.tscn`, instanciada en `GameUI` como
   `Root/OptionsView`; ver "Vistas modales" en las Convenciones):
   - raíz `Control` a pantalla completa con `mouse_filter = STOP` y, centrado,
     un `PanelContainer` con el pergamino del tema;
   - "Música" (`HSlider` 0–1, paso 0,05), "Efectos" (ídem), "Silencio"
     (`CheckBox`), "Pantalla completa" (`CheckBox`, oculto si no se permite) y
     "Volver";
   - se abre con un botón "Opciones" en la vista de título y en la de pausa;
     mientras está abierta, la vista que la abrió se oculta y al pulsar
     "Volver" reaparece;
   - **se cierra sola** (como si se pulsara "Volver", guardando) si cambia el
     estado de la partida o se despausa con Esc/P: si no, quedaría abierta
     sobre una partida en marcha y "Volver" mostraría una pausa que ya no
     existe. `GameUI.set_paused(false)` y `_on_state_status_changed` la cierran;
   - al soltar el slider de efectos (`drag_ended`), `sfx_preview_requested` →
     `GameUI.button_pressed` → suena el clic de la interfaz.
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
     `DisplayDirector.setup(allow_fullscreen, config)` y a
     `_ui.set_platform(true, allow_fullscreen, false)`;
   - guarda también en `NOTIFICATION_WM_CLOSE_REQUEST` (cerrar la ventana con
     la X sin pasar por "Volver").
6. Documenta en `07` §5 (buses y ajustes del jugador frente a la atenuación del
   juego) y §6 (vista de opciones), y en `04` §4 (F11). En `02` (380 líneas,
   muy justo): una fila por componente nuevo en la tabla de §4 (`SettingsStore`
   en la capa **Sesión**, como `ScoreStore`, no en Simulación;
   `DisplayDirector` y `OptionsView` en Presentación), y su nodo en el árbol de
   §5. Las descripciones largas van en `07`. Si no cabe, compacta antes otra
   sección de `02` sin perder contenido.

### Tests

- `test_settings_store.gd` (nuevo, ruta `user://test_settings.cfg` borrada en
  `after_each`): valores por defecto; los setters acotan a [0, 1]; `save` y
  otra instancia con la misma ruta los lee; sin `save` no se escribe; archivo
  corrupto y tipo inesperado → valores por defecto; ruta vacía nunca toca el
  disco; `changed` se emite al cambiar un valor y no al repetir el mismo.
- `test_audio_director.gd`: `apply_settings` pone el volumen de los buses
  `Music` y `SFX`; volumen 0 → bus en mute; `muted` → `Master` en mute.
  Restaura los buses en `after_each`.
- `test_options_view.gd` (nuevo): mover un slider emite su señal;
  `show_settings` actualiza los controles **sin** emitir señales;
  `set_allow_fullscreen(false)` oculta la casilla; la raíz cubre toda la
  pantalla y su `mouse_filter` es `STOP`.
- `test_game_ui.gd`: "Opciones" desde título y desde pausa abre la vista y
  oculta la de origen; "Volver" emite `options_closed` y la restaura;
  `set_paused(false)` y un cambio de estado la cierran; `set_platform`
  aplicado **después** de `setup` cambia la visibilidad.
- `test_session_integration.gd`: `mute_requested` alterna
  `get_settings().is_muted()` y el mute del bus `Master`, también en pausa;
  en `READY` con Opciones abierta, un clic fuera del panel no empieza la
  partida (envía el evento con `Input.parse_input_event` o
  `get_viewport().push_input` para que pase por la GUI).

**Commit:** `feat(opciones): volumen de música y efectos, silencio y pantalla completa persistentes`

---

## Fase 2 — Distribución de escritorio

### Contrato

```gdscript
# ui/credits_view.gd + ui/credits_view.tscn (nuevo; misma estructura modal
# que OptionsView)
class_name CreditsView
extends Control
signal closed
func set_version(version: String) -> void

# ui/game_ui.gd (añadidos; `allow_quit` llega por `set_platform`)
signal quit_requested
## Texto de versión (`application/config/version`), en la vista de título y
## en los créditos.
func set_version(version: String) -> void
```

### Pasos

1. **Versión.** `application/config/version="0.3.0"` en `project.godot`.
   `Main` la lee (`ProjectSettings.get_setting`) y llama a `_ui.set_version`;
   la vista de título la muestra pequeña ("v0.3.0") en su esquina inferior.
2. **Icono de la aplicación.**
   - Nueva entrada en `tools/asset_spec.gd`: `assets/ui/app_icon.png`,
     512×512. En `tools/generate_placeholders.gd`, `_make_image` necesita una
     rama `app_icon` (hoy los nombres desconocidos caen en `sparkle()`) que
     dibuje la silueta de un alambique o matraz sobre fondo redondeado, con
     los colores del tema; y su plantilla en `docs/plantillas/` con la zona
     segura (círculo de 410 px, como los materiales). Ejecuta el generador
     **sin** `--force` y con `-- --templates` (sin ese argumento no escribe
     plantillas), y después `godot --headless --path . --import`.
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
   `_settings.save()`, para la música y sale **unos frames después** (p. ej.
   `await get_tree().create_timer(0.1).timeout` antes de `get_tree().quit()`):
   salir en el mismo frame deja la reproducción sin liberar (fase 0, paso 2).
   `allow_quit` = `not OS.has_feature("web")`, por `set_platform`.
4. **Créditos.** Botón "Créditos" en la vista de título → `CreditsView`
   (`ui/credits_view.tscn`, instanciada en `GameUI`; modal como `OptionsView`,
   con "Volver"): nombre del juego, versión, autoría, y un `ScrollContainer`
   (con `custom_minimum_size.y`, o se colapsa a 0 de alto) con:
   - "Hecho con Godot Engine" y `Engine.get_license_text()` (la licencia MIT
     de Godot obliga a incluir el aviso en las copias distribuidas);
   - los textos de licencia de terceros de `Engine.get_license_info()`. La
     guía oficial "Complying with licenses" exige incluir también los de
     FreeType, ENet y mbedTLS: no basta con los nombres;
   - un hueco para la licencia OFL de la fuente, que se rellena al integrarla.
   La autoría y el texto exacto son decisión del usuario (ver "Decisiones
   abiertas"); deja un texto provisional claro ("Autor: por definir").
5. **Presets de exportación.** Quita `export_presets.cfg` de `.gitignore`: los
   presets de escritorio y web no contienen secretos (los de Android sí, con el
   *keystore*; nunca se suben). Crea `export_presets.cfg` a mano con estos dos
   presets. **Verificado:** en un `git clone` limpio (sin `.godot/`),
   `--import` seguido de `--export-release` funciona con estos presets escritos
   a mano, todas las claves existen en 4.7.2 y Godot no reescribe el archivo.
   La carpeta de destino debe existir antes de exportar.

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
   salida contiene `SCRIPT ERROR` o cualquier `ERROR`/`WARNING`, **salvo** las
   dos líneas exactas de la fuga de la fase 0 (`ObjectDB instances were leaked
   at exit` y `resources still in use at exit`) mientras sigan anotadas como no
   resueltas: con `--quit-after` el juego no pasa por "Salir" y la fuga aparece
   siempre (verificado en el binario exportado). Además empaqueta
   `dist/el_alquimista_pobre_linux.zip` y `…_windows.zip` (el zip conserva el
   permiso de ejecución del binario de Linux; itch.io lo necesita). En la fase
   5 se le añade la web.
7. **Comprobaciones manuales del build de release** (anótalas en el commit):
   - arranca con la pantalla de título y se juega una partida completa;
   - F1–F4 y F12 no hacen nada (`DebugController` solo actúa en builds de
     depuración);
   - el récord y los ajustes se guardan en `user://` del build exportado
     (`~/.local/share/godot/app_userdata/El Alquimista Pobre/`);
   - el tamaño de los binarios (anótalo en `07` §7 como referencia; medidos en
     la revisión: Linux 74 MB, Windows 110 MB).
   El `.exe` de Windows **no** se ejecuta (nada de wine; ver regla 9): basta
   con que el export se genere. Arrancarlo en Windows queda en la lista de
   comprobaciones manuales del usuario en `07`.
8. **Splash de arranque.** Hoy sale el de Godot. Pon
   `application/boot_splash/bg_color` con el color de fondo del juego
   (`environment/defaults/default_clear_color`) y
   `application/boot_splash/show_image=false`: un arranque limpio sin imagen
   de terceros. Un splash propio queda para cuando haya arte.
9. README: sección "Builds" con `tools/export_all.sh`, las rutas de `dist/`,
   dónde guarda los datos el juego y las plataformas: Linux, Windows y Web.
   **macOS queda fuera** (requiere firma y notarización).

### Tests

- `test_asset_spec.gd` ya cubre el icono al estar en la especificación; añade
  `test_project_icon_is_the_app_icon` (lee `application/config/icon`).
- `test_game_ui.gd`: con `set_platform(false, …)` no se ve ningún "Salir";
  "Salir" emite `quit_requested`; "Créditos" abre la vista; `set_version` se ve
  en el título.
- `test_credits_view.gd` (nuevo): el texto contiene la primera línea de
  `Engine.get_license_text()` ("Copyright (c) 2014-present Godot Engine
  contributors…") y las licencias de FreeType, ENet y mbedTLS; la raíz cubre
  la pantalla con `mouse_filter = STOP`; "Volver" emite `closed`.
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
## `top_clearance`: espacio libre que hace falta por encima del interior del
## recipiente para la pieza en `spawn_y` y el artefacto. Lo calcula Main
## (radio máximo soltable + lado del artefacto − `spawn_y`) para que `compute`
## siga siendo pura y no escriba ese número a mano.
static func compute(visible_size: Vector2, orientation: Orientation,
		config: GameConfig, top_clearance: float) -> ScreenLayout

# ui/display_director.gd (añadidos; `setup(allow_fullscreen, config)` ya
# existe desde la fase 1)
signal layout_changed(layout: ScreenLayout)
## Espacio libre sobre el recipiente (ver `ScreenLayout.compute`). Main lo
## asigna antes de la primera disposición.
func set_top_clearance(clearance: float) -> void
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
   exterior ocupa el 87 %). Cuentas verificadas en la revisión, con
   `container_width = 440`, `container_height = 600`, `wall_thickness = 32`,
   `spawn_y = 40`, radio máximo soltable 46 (nivel 5) y artefacto de 64:
   - recipiente centrado en horizontal con `board_origin.y = 220`: interior
     x 68–508, y 220–820; exterior (con paredes) x 36–540, y 220–852. El
     artefacto llega hasta `220 + 40 − 46 − 64 = 150`;
   - franja superior **y 16–116** (el bloque de puntuación sin título mide
     98 px, medido): puntuación y récord a la izquierda, PRÓXIMO a la derecha,
     y el botón de pausa (fase 4) en la esquina superior derecha, a la
     izquierda de PRÓXIMO; sin el título del HUD (ya está en la vista de
     título). Entre 116 y 150 queda margen;
   - leyenda debajo del recipiente, en **2 columnas** × 4 filas: y 868–982
     (4 × 24 + 3 × 6 = 114 px, medido); filas de hasta 236 px de ancho, así
     que 2 columnas ≈ 480 en 544 disponibles;
   - si el alto visible supera 1024 (móviles alargados), todo el bloque se
     centra en vertical: se suma `(alto_visible − 1024) / 2` a cada `y`;
   - con F4 (depuración, nivel 7, r = 68) el artefacto sube hasta y ≈ 108 y
     puede tapar la franja: aceptable, es solo de depuración.
   Si los datos cambian y algo deja de caber, ajusta las constantes de
   `ScreenLayout`, no los datos del juego.
   - En horizontal (1280×720) el suelo acaba en y 712 < 720 y los paneles quedan
     fuera de x 388–892 (verificado). El botón de pausa va en la esquina
     superior derecha (32 px de margen), encima de PRÓXIMO.
   - `DebugLabel` está anclado abajo a la izquierda y en vertical tapa la
     leyenda: muévelo a la esquina superior izquierda en vertical (solo
     depuración).
3. **`ScreenLayout.compute` es pura.** Ningún nodo, ninguna consulta a la
   ventana: recibe el tamaño visible y devuelve rectángulos. Así se prueba con
   cualquier tamaño de pantalla sin abrir ventanas.
4. **`DisplayDirector`** escucha `get_tree().root.size_changed`:
   1. calcula la orientación con `get_window().size` (píxeles físicos);
   2. si su base difiere de `get_window().content_scale_size`, la asigna y
      **retorna**: asignarla emite `size_changed` de forma síncrona
      (reentrante), y esa llamada interna ya calcula y emite la disposición.
      Sin el `return`, `layout_changed` se emitiría dos veces (verificado;
      asignar el mismo valor no emite, así que no hay bucle);
   3. calcula `ScreenLayout.compute(get_viewport().get_visible_rect().size, …)`
      y emite `layout_changed`.
   En GUT headless la ventana mide 64×64: cuenta como `LANDSCAPE`, la base ya
   coincide y los tests no cambian el estado global de la ventana.
   Al llamar a `setup`, hace lo mismo una vez para que `Main` tenga la
   disposición inicial.
5. **`Main`**: elimina `_update_world_position` y su conexión a
   `size_changed` (y reescribe el párrafo de `02` §5 que lo describe); calcula
   `top_clearance` con `config.piece_catalog`, la estrategia y
   `DropPreview.dropper_size`, y lo pasa con `set_top_clearance`; conecta
   `layout_changed` a un callback que hace
   `_world.position = layout.board_origin` y `_ui.apply_layout(layout)`.
   `DropSystem.request_aim_global` ya convierte a coordenadas de tablero con
   `to_local`, así que el apuntado con ratón no cambia.
6. **`game_ui.tscn`**: separa `LeftPanel`/`RightPanel` en `ScorePanel`
   (título, puntuación, récord), `NextPanel` (etiqueta + icono) y `LegendPanel`
   (un `GridContainer`; `columns` = `legend_columns`). `apply_layout` asigna
   `position` y `size` de cada panel desde los rectángulos (sin anclas). Las
   vistas centradas (título, pausa, opciones, créditos, fin) siguen ancladas al
   centro y caben en 576 de ancho (la más ancha mide 400, medido).
   **Tests que se rompen** al renombrar y cambiar el tipo de la leyenda
   (`VBoxContainer` → `GridContainer`): `test_game_ui.gd` (líneas ~26, 31, 36,
   81–87, 102, 110, 172 y 188, con casts `as VBoxContainer`) y
   `test_session_integration.gd` (~110). Actualízalos en el mismo commit y añade
   los paneles nuevos a `test_non_interactive_containers_ignore_mouse`.
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
      paredes, y `top_clearance` por encima del interior; usa el valor real que
      calcula `Main` con los datos del juego, 70 hoy);
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
  `device == InputEvent.DEVICE_ID_EMULATION` (−1), que llega **antes** que el
  toque. Un ratón real usa `InputEvent.DEVICE_ID_MOUSE` (32; es lo que trae
  `InputEventMouseButton.new()`; con un ratón físico es sospecha razonable, no
  verificado). El filtro compara con `DEVICE_ID_EMULATION`, que sí está
  verificado.
- `InputEventScreenTouch.canceled` existe en 4.7.
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

# ui/game_ui.gd (añadidos; `touch_hints` llega por `set_platform`: textos
# para pantalla táctil, "Toca para empezar" y "Reiniciar" sin "(R)")
signal pause_requested           # botón de pausa del HUD
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
3. **Tamaño táctil.** Con `touch_hints`, en **cualquier** orientación, los
   botones de las vistas usan la variación de tema `TouchButton` (alto mínimo
   64 unidades en vertical ≈ 44 px CSS en un móvil de 390 de ancho; en
   horizontal la escala es menor —844×390 da ≈ 0,54—, así que el alto en
   horizontal debe ser ~80 unidades para no quedarse en ~22 px CSS). Asígnala
   en `set_platform`/`apply_layout`, no con overrides sueltos.
4. **Textos.** `Main` pasa `touch_hints = DisplayServer.is_touchscreen_available()`
   con `set_platform`.
   Con `touch_hints`: "Toca para empezar" en el título y "Reiniciar" en las
   vistas de fin.
5. **Prueba en escritorio.** No hay forma limpia de emular el táctil con el
   ratón sin duplicar eventos (`emulate_touch_from_mouse` generaría ambos). La
   lógica se prueba con eventos sintéticos en los tests; el dispositivo real
   lo prueba el usuario (fase 5).
6. Actualiza `04` §4 (tabla de gestos) y `07` §6 (botón de pausa, textos
   táctiles, tamaño de botones).

### Tests

- `test_drop_controller.gd` (llamando a `_unhandled_input` con eventos
  sintéticos, como ya hace):
  - clic y movimiento con `device = DEVICE_ID_EMULATION` no emiten nada;
  - con `device = InputEvent.DEVICE_ID_MOUSE`, el ratón sigue funcionando como
    antes;
  - apoyar → `aim_requested(x)`; arrastrar → `aim_requested(x2)`; levantar →
    `drop_requested` una sola vez;
  - un segundo dedo (otro índice) no apunta ni suelta;
  - levantar con `canceled = true` no suelta;
  - pausar con un dedo apoyado y despausar: levantar no suelta.
- `test_game_ui.gd`: el botón de pausa solo se ve en `PLAYING` y emite
  `pause_requested`; con `set_platform(…, touch_hints = true)` cambian los
  textos y los botones usan `TouchButton`.
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
   - `allow_fullscreen`: en web solo en navegadores de escritorio:
     `not (OS.has_feature("web_android") or OS.has_feature("web_ios"))` (los
     *feature tags* existen en la plantilla web de 4.7.2, verificado). Que el
     cambio de modo funcione en web es **dudoso**: el navegador exige que ocurra
     dentro del gesto del usuario y Godot puede procesar la entrada fuera de ese
     callback. Queda en la lista de comprobación del usuario; si falla, oculta
     la casilla en web y confía en el botón de pantalla completa de itch.io.
3. **Audio.** Los navegadores no dejan sonar nada hasta el primer gesto del
   usuario; Godot reanuda el audio en la primera entrada. La pantalla de
   título garantiza ese gesto. Va a la lista de comprobación del usuario: si
   la música no empieza al primer clic o toque, la corrección (en otra
   iteración) es arrancarla la primera vez que el estado pase a `PLAYING`.
4. **Persistencia.** En web, `user://` vive en IndexedDB. `Main` imprime
   `OS.is_userfs_persistent()` al arrancar, solo en builds de depuración. Con
   `false` (navegación privada), récord y ajustes funcionan en memoria sin
   errores (ya lo garantiza la ruta de error de `ScoreStore` y
   `SettingsStore`). Que el récord sobreviva a recargar la página va a la
   lista de comprobación.
5. **Pausa al cambiar de pestaña.** `NOTIFICATION_APPLICATION_FOCUS_OUT` debería
   llegar al ocultar la pestaña; va a la lista de comprobación (si no llega,
   se anota; no se sustituye por JavaScript).
6. **`tools/export_all.sh`**: añade el preset Web y un zip con `index.html` en
   la **raíz** (`cd dist/web && zip -r ../el_alquimista_pobre_web.zip .`;
   itch.io no encuentra el juego si va dentro de una carpeta). El wasm pesa
   ~39 MB: anótalo en `07` (afecta a la carga con datos móviles).
7. **Prueba local (manual, del usuario; el agente no levanta servidores ni
   abre navegadores):** documenta en el README
   `python3 -m http.server 8000 -d dist/web` y abrir `http://localhost:8000`
   en Chrome y Firefox; para un móvil en la misma red,
   `http://<IP-del-equipo>:8000`. Si el navegador del móvil exige contexto
   seguro, usar un borrador privado en itch.io (paso 9).
8. **Lista de comprobación en dispositivo** (créala en `07` §8, nueva, con
   columnas navegador/dispositivo/resultado, todo "sin probar"; la rellena el
   usuario):
   - carga y pantalla de título; música tras el primer toque;
   - vertical y horizontal, y girar el móvil en mitad de la partida;
   - arrastrar y soltar; botón de pausa; opciones (volúmenes, silencio);
   - récord tras recargar la página;
   - pausa al cambiar de pestaña;
   - fluidez con el recipiente casi lleno (subjetiva; anota el modelo);
   - pantalla completa desde Opciones (escritorio);
   - el `.exe` de Windows arranca y se juega (fase 2).
9. **itch.io** (solo instrucciones en el README; publicar es decisión del
   usuario): proyecto HTML, subir el zip, "This file will be played in the
   browser", tamaño de ventana 1280×720, "Mobile friendly" con orientación
   por defecto, botón de pantalla completa activado, **sin** "SharedArrayBuffer
   support".
10. README: añade "Web" a la sección "Builds".

### Tests

- La web no se prueba con GUT, y los *flags* de plataforma ya los cubren los
  tests de `set_platform` en `test_game_ui.gd`. No hace falta un test nuevo.

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
| macOS | Fuera (firma y notarización) | Siguiente iteración |
| Splash propio al arrancar | Sin imagen, solo color de fondo, hasta que haya arte | Al integrar el arte |

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
