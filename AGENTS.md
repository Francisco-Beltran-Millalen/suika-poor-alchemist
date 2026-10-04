# El Alquimista Pobre — Contexto del proyecto

Puzzle de física y fusión inspirado en **Suika Game**, ambientado en un taller alquímico
donde un alquimista chatarrero fusiona materiales de bajo valor (basura, metales comunes)
hasta transmutar elementos legendarios (la Piedra Filosofal).

Godot **4.7** · GDScript con **tipado estático obligatorio**.

Documentos canónicos de diseño en `docs/`:
- `docs/01_diseno_general.md` — Visión y bucle principal
- `docs/02_technical_design.md` — Arquitectura técnica y desacoplamiento
- `docs/03_data_design.md` — Recursos, datos y parámetros configurables
- `docs/04_gameplay_design.md` — Mecánicas de juego y resolución de fusiones
- `docs/05_plan_implementacion.md` — Plan de implementación paso a paso (guía temporal, no diseño canónico)
- `docs/el_alquimista_pobre_concepto.md` — Fantasía y progresión visual
- `docs/RULES.md` — Convenciones de código y estilo obligatorio

---

## Comandos

```bash
# Tests con GUT (ejecución por línea de comandos)
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Ejecutar un solo archivo de test
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_smoke.gd -gexit

# Reimportar assets y actualizar caché de clases globales
godot --headless --path . --import

# Ejecutar la escena principal
godot --path . --scene res://game/main.tscn

# Ver formas de colisión durante la ejecución
godot --path . --debug-collisions --scene res://game/main.tscn

# Simulación de balance (bot aleatorio por estrategia, CSV + resumen)
godot --headless --fixed-fps 60 -s tools/balance_sim.gd -- --games=5

# Captura de fotogramas con Movie Maker (requiere ventana, no usar --headless)
godot --path . --scene res://game/main.tscn \
      --write-movie /tmp/mov/shot.png --fixed-fps 60 --quit-after 120
```

---

## Principios de Arquitectura

El diseño sigue estrictamente la separación de responsabilidades definida en `docs/02_technical_design.md`:

```text
PRESENTACIÓN ──▶ SIMULACIÓN ──▶ DATOS      (A ──▶ B = "A depende de B")
```

- **Datos (`PieceData`, `PieceCatalog`, `SpawnStrategy`, `GameConfig`):** Son `Resource` inmutables durante la simulación. No conocen la simulación ni la escena.
- **Simulación (`GameState`, `Board`, `Piece`, `PieceSpawner`, `DropSystem`, `MergeSystem`, `DangerSystem`, `ProgressSystem`):** Gobiernan la física y las reglas de juego. Desconocen completamente la presentación y la UI.
- **Presentación (`GameUI`, `DropController`, `DropPreview`, `EffectsLayer`):** Observa eventos y señales de la simulación. Traduce las entradas del jugador en intenciones o comandos hacia los sistemas. No contiene lógica de reglas ni de puntuación.
- **Composition Root (`game/main.tscn` / `game/main.gd`):** La raíz `Main` es el único ensamblador de la partida. Conecta señales e inyecta dependencias. Nunca usar rutas absolutas como `get_node("/root/...")`.
- **Autoloads mínimos:** No usar autoloads como contenedores globales de conveniencia. El estado de la partida vive en su árbol de composición.
- **Límite duro de 400 líneas por archivo:** Aplica al código y a la documentación permanente. No crear archivos que lo superen; modularizar mediante componentes o sistemas específicos. Los planes de implementación temporales están exentos.

---

## Estructura de Directorios

Organización guiada por dominio (siguiendo §11 de `docs/02_technical_design.md`):

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

## Cómo trabajar aquí

1. **El motor primero:** Antes de crear lógica personalizada para física, áreas o colisiones, aprovechar los nodos y capacidades nativas de Godot (`RigidBody2D`, `Area2D`, `CollisionShape2D`, etc.).
2. **Tipado estático obligatorio:** Todo método debe definir tipos de parámetros y valor de retorno (`-> void`, `-> bool`, etc.). Variables tipadas explícitamente (`var x: int = 0`), usando `:=` solo cuando la inferencia es inmediata.
3. **Tests:** Toda nueva lógica de simulación (fusión, detección de peligro, límites de colocación) debe acompañarse de sus tests GUT en `tests/unit/` o `tests/integration/`.
4. **Commits en español con ámbito:** Formato `type(ámbito): qué cambia, en español` (ej. `feat(merge): resolución de colisiones entre piezas iguales`).
