# El Alquimista Pobre

Juego de puzzle y física inspirado en la mecánica de **Suika Game**, ambientado en un
taller alquímico donde un alquimista chatarrero transmuta materiales desde chatarra
y metales comunes hasta la mítica Piedra Filosofal.

Estado: **jugable de principio a fin**; iteración 2 implementada (fases 0–8) salvo las pruebas de balance con partidas humanas y el arte, la fuente y el audio definitivos ([`docs/06_plan_iteracion_2.md`](docs/06_plan_iteracion_2.md)).

---

## Stack

| Aspecto        | Elección                                        |
| -------------- | ----------------------------------------------- |
| Motor          | Godot 4.7 (GL Compatibility)                    |
| Lenguaje       | GDScript con tipado estático obligatorio        |
| Pruebas        | GUT (Godot Unit Test) en `addons/gut/`          |
| Arquitectura   | Separación estricta Datos → Simulación → Presentación |
| Convenciones   | Detalladas en [`docs/RULES.md`](docs/RULES.md)  |

---

## Estructura del proyecto

Organización orientada a dominio según la recomendación oficial de Godot:

```text
res://
├── game/             # Composition root (main.tscn) y GameConfig
├── board/            # Recipiente físico y zona de peligro
├── piece/            # Piezas físicas y PieceData (recursos)
├── systems/          # Sistemas de simulación (caída, fusión, peligro)
├── ui/               # Presentación e interfaz de usuario
├── tools/            # Scripts de línea de comandos (simulación de balance)
├── assets/           # Sprites, shaders, sonidos y fuentes (placeholders generados)
├── tests/            # Suite de pruebas automatizadas con GUT
│   ├── unit/         # Tests unitarios
│   └── integration/  # Tests de integración
├── addons/           # Dependencias externas (GUT)
├── docs/             # Documentación, GDDs y especificaciones (.gdignore)
└── project.godot
```

---

## Comandos rápidos

```bash
# Ejecutar la suite de tests
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Ejecutar el juego
godot --path . --scene res://game/main.tscn

# Simulación de balance por estrategia (bot aleatorio)
godot --headless --fixed-fps 60 -s tools/balance_sim.gd -- --games=5

# Inspeccionar colisiones en tiempo de ejecución
godot --path . --debug-collisions --scene res://game/main.tscn
```

---

## Documentación de diseño

- [`docs/01_diseno_general.md`](docs/01_diseno_general.md) — Visión general y bucle de juego.
- [`docs/02_technical_design.md`](docs/02_technical_design.md) — Arquitectura técnica y pruebas de desacoplamiento.
- [`docs/03_data_design.md`](docs/03_data_design.md) — Especificación de datos y balance configurable.
- [`docs/04_gameplay_design.md`](docs/04_gameplay_design.md) — Reglas detalladas de colocación y fusión.
- [`docs/05_plan_implementacion.md`](docs/05_plan_implementacion.md) — Plan de implementación paso a paso (guía temporal).
- [`docs/06_plan_iteracion_2.md`](docs/06_plan_iteracion_2.md) — Plan de la iteración 2 (guía temporal).
- [`docs/08_plan_iteracion_3.md`](docs/08_plan_iteracion_3.md) — Plan de la iteración 3: opciones, distribución, táctil y web (guía temporal).
- [`docs/07_diseno_presentacion.md`](docs/07_diseno_presentacion.md) — Arte, escenario, efectos, audio y pantallas.
- [`docs/el_alquimista_pobre_concepto.md`](docs/el_alquimista_pobre_concepto.md) — Progresión de valor y ambientación.
- [`docs/RULES.md`](docs/RULES.md) — Guía de estilo y reglas de codificación.
- [`docs/notas_playtest.md`](docs/notas_playtest.md) — Simulación de balance y notas de partidas.

---

## Depuración (solo builds de depuración)

`F1`/`F2`/`F3` cambian la estrategia de generación (clásica, uniforme 1–4,
ponderada) y reinician la partida; `F4` sustituye el ACTUAL por una pieza de
nivel alto; `F12` muestra FPS, piezas y semilla.

## Exportación

`export_presets.cfg` no se versiona. Al crear el preset de exportación hay que
**excluir `tools/*`** de los recursos exportados (paso manual).
