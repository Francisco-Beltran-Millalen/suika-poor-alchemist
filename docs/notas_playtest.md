# Notas de balance y pruebas de juego

Documento de trabajo de la iteración 2 (`docs/06_plan_iteracion_2.md`, fases 1 y 8).
Las notas de partidas humanas las escribe el usuario; este archivo no contiene
sensaciones inventadas.

---

## Simulación automática

- Fecha: 2026-10-03. Versión: commit `2015375` (`feat(debug)`) con `tools/balance_sim.gd`.
- Jugador: bot que suelta en una X aleatoria cada vez que puede (cooldown 0,5 s).
- **Qué mide:** dificultad *relativa* entre estrategias frente a un jugador
  aleatorio. No mide la diversión ni lo difícil que es para una persona.
- Tope por partida: 10 min simulados (ninguna partida lo alcanzó).
- Comando: `godot --headless --fixed-fps 60 -s tools/balance_sim.gd -- --games=N`

Por defecto (5 semillas por estrategia, ~20 s de tiempo real):

```text
== Resumen (medias por estrategia, 5 partidas cada una) ==
estrategia              soltadas nivel_max    puntos  segundos victorias
spawn_suika_classic         78.2       7.8     716.6      40.3     1/5
spawn_uniform_1_4          127.6       7.4    1062.2      65.8     0/5
spawn_weighted             123.0       7.8    1165.8      63.4     4/5
Tiempo real: 20.3 s
```

Con 20 semillas por estrategia (~80 s de tiempo real):

```text
== Resumen (medias por estrategia, 20 partidas cada una) ==
estrategia              soltadas nivel_max    puntos  segundos victorias
spawn_suika_classic         80.8       7.9     731.1      41.6     2/20
spawn_uniform_1_4          135.8       7.8    1196.8      70.0     1/20
spawn_weighted             123.8       8.0    1158.8      63.9    10/20
Tiempo real: 81.1 s
```

### Lectura de los datos

- Con un jugador aleatorio, `spawn_suika_classic` (niveles 1–5 uniformes) es la
  más dura: pierde en ~40 s y apenas gana (2/20).
- `spawn_weighted` es la más fácil de ganar (10/20), porque genera menos piezas
  grandes que estorban y la cadena crece desde abajo.
- `spawn_uniform_1_4` aguanta más soltadas, pero gana poco (1/20): casi no
  genera piezas altas y necesita muchas más fusiones para llegar a la Piedra.
- Son datos para contrastar con las partidas humanas de la fase 8; no justifican
  por sí solos ningún cambio de balance.
