# El Alquimista Pobre

Juego de puzzle y física inspirado en la mecánica de **Suika Game**, ambientado en un
taller alquímico donde un alquimista chatarrero transmuta materiales desde chatarra
y metales comunes hasta la mítica Piedra Filosofal.

Estado: **jugable de principio a fin**; iteración 2 en curso ([`docs/06_plan_iteracion_2.md`](docs/06_plan_iteracion_2.md)).

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
├── assets/           # Sprites, shaders, sonidos y fuentes
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
- [`docs/el_alquimista_pobre_concepto.md`](docs/el_alquimista_pobre_concepto.md) — Progresión de valor y ambientación.
- [`docs/RULES.md`](docs/RULES.md) — Guía de estilo y reglas de codificación.
