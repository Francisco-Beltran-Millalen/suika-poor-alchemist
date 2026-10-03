# Diseño de gameplay

## 1. Objetivo

Este documento define las reglas jugables de la primera implementación de
**El Alquimista Pobre**, con la precisión suficiente para implementarlas y
probarlas sin tomar decisiones de diseño durante la programación.

No define la arquitectura (`02_technical_design.md`), los valores de los datos
(`03_data_design.md`) ni el estilo artístico final.

---

## 2. Fantasía jugable

El jugador encarna a un alquimista chatarrero. Con su artefacto deja caer
materiales baratos en un recipiente, y cuando dos materiales iguales se tocan
se transmutan en uno más valioso. La meta es crear dos Piedras Filosofales y
fusionarlas.

El desafío consiste en:

- elegir la posición de cada soltada;
- anticipar cómo caerá y rodará el material;
- agrupar materiales iguales;
- mantener espacio libre;
- evitar que el recipiente se llene por encima de la línea de peligro.

---

## 3. Bucle de juego (tiempo real)

El juego es **continuo, no por turnos**. La física y las fusiones nunca se
pausan entre soltadas.

```text
┌──────────────────────────────────────────────────────────────┐
│ El jugador ve el material ACTUAL (sobre el recipiente)       │
│ y el PRÓXIMO (en la UI)                                      │
│        ↓                                                     │
│ Apunta horizontalmente                                       │
│        ↓                                                     │
│ Suelta → el ACTUAL cae; el PRÓXIMO pasa a ser ACTUAL;        │
│          se genera un nuevo PRÓXIMO                          │
│        ↓                                                     │
│ Espera el cooldown (0.5 s) → puede volver a soltar           │
└──────────────────────────────────────────────────────────────┘

En paralelo, de forma continua:
  física → contactos → fusiones → cascadas → puntuación
  comprobación de peligro → Game Over
  fusión de dos piezas de nivel máximo → Victoria
```

No se espera a que el tablero se estabilice para la siguiente soltada. Solo
existe el cooldown fijo `drop_cooldown`, como en Suika. Durante el cooldown el
jugador puede seguir apuntando.

---

## 4. Control del jugador

| Acción (InputMap) | Teclas por defecto            | Efecto                                   |
| ----------------- | ----------------------------- | ---------------------------------------- |
| apuntar (ratón)   | movimiento del ratón          | La posición X sigue al cursor            |
| `aim_left`        | `A`, `←`                      | Mueve la posición a `aim_speed` px/s     |
| `aim_right`       | `D`, `→`                      | Mueve la posición a `aim_speed` px/s     |
| `drop`            | clic izquierdo, `Espacio`     | Suelta el material actual                |
| `restart`         | `R`                           | Reinicia (solo en Game Over o Victoria)  |

- El jugador solo elige la posición **horizontal**. La vertical es fija
  (`spawn_y`).
- Mientras apunta, el material actual se dibuja en su posición de soltado,
  junto con una **línea guía vertical** hasta el fondo.
- Una vez soltado, el material queda bajo el control exclusivo de la física.
  No se puede agarrar, detener ni empujar.

---

## 5. Colocación

Al soltar:

1. La posición X se limita a `[radius, container_width − radius]` según el
   radio del material **actual**. Una pieza nunca aparece dentro de una pared.
2. Se crea la pieza en `(x, spawn_y)` con velocidad cero, en estado
   `DROPPING`.
3. La cola avanza: ACTUAL ← PRÓXIMO; PRÓXIMO ← nueva pieza generada.
4. Empieza el cooldown. Hasta que termine, se ignoran nuevas órdenes de
   soltado.

El límite del paso 1 también se aplica a la vista previa mientras se apunta,
de modo que el jugador ve exactamente dónde caerá. Cada vez que cambia el
material actual, la posición se limita con su radio. La posición elegida por
el jugador se conserva sin limitar, así que al pasar a un material más pequeño
vuelve a donde el jugador apuntó.

Al soltar no se otorgan puntos.

---

## 6. Generación del próximo material

La regla se define por datos (`GameConfig.spawn_strategy`, ver
`03_data_design.md` §7) y se puede cambiar sin tocar código:

- **Por defecto, Suika clásico**: uniforme entre los niveles 1 y 5.
- **Uniforme 1–4**: variante más fácil.
- **Ponderada**: pesos `[40, 25, 18, 11, 6]` para los niveles 1–5.

Nunca se genera el nivel máximo. Las tres variantes se evaluarán en pruebas de
juego.

Al iniciar la partida se generan dos piezas: ACTUAL y PRÓXIMO.

---

## 7. Estados de una pieza

Cada pieza del recipiente tiene un estado de juego:

| Estado     | Significado                                              | Cuenta para peligro | Puede fusionarse |
| ---------- | -------------------------------------------------------- | ------------------- | ---------------- |
| `DROPPING` | Recién soltada; aún no tocó nada                         | No                  | Sí               |
| `ACTIVE`   | Ya tocó algo (suelo, pared u otra pieza)                 | Sí                  | Sí               |
| `CONSUMED` | Aceptada para una fusión; pendiente de eliminación       | No                  | No               |

- `DROPPING → ACTIVE`: en el primer contacto físico con cualquier cuerpo,
  **incluidas las paredes**. Una pieza soltada pegada a la pared pasa a
  `ACTIVE` casi al instante, sobre la línea. Es aceptable, porque sale de la
  zona en mucho menos que `game_over_delay`.
- Las piezas creadas por fusión nacen directamente en `ACTIVE`.
- `CONSUMED` es terminal.

La exención de `DROPPING` es necesaria porque `spawn_y` está **por encima** de
la línea de peligro: todas las piezas soltadas la atraviesan al caer.

---

## 8. Regla de fusión

Dos piezas se fusionan si y solo si:

1. están en contacto físico;
2. son **del mismo tipo** (`a.data == b.data`, identidad del recurso);
3. ninguna de las dos está en estado `CONSUMED`;
4. son piezas distintas;
5. la partida está en estado `PLAYING`.

Una pieza de un nivel distinto no se ve afectada por el contacto.

---

## 9. Resolución de una fusión

Cuando un contacto cumple §8:

1. **Inmediatamente**, ambas piezas pasan a `CONSUMED`. Desde ese momento
   ninguna otra fusión puede usarlas.
2. La resolución se **difiere** al siguiente paso de simulación. Godot no
   permite crear ni eliminar cuerpos mientras procesa contactos.
3. Al resolver, primero **se eliminan A y B**, de modo que la nueva pieza
   nunca se solapa con ellas.
4. Se calcula la posición resultante: el **punto medio** entre A y B, limitado
   a `x ∈ [r, width − r]` y `y ≤ height − r`, donde `r` es el radio de la
   nueva pieza.
5. Se crea la pieza de nivel `next_piece` en esa posición, con velocidad cero
   y estado `ACTIVE`.
6. Se otorga `next_piece.score_value` a la puntuación.

La nueva pieza es una pieza normal: cae, choca y puede fusionarse de nuevo.

### 9.1. Fusión de dos piezas de nivel máximo → Victoria

Si A y B son del nivel máximo (`next_piece == null`):

1. Ambas pasan a `CONSUMED` y se eliminan (pasos 1–3 de §9).
2. No se crea ninguna pieza.
3. Se otorga `victory_bonus`.
4. La partida pasa a `VICTORY` (ver §13).
5. La presentación reproduce la animación de victoria en el punto de fusión.

---

## 10. Cascadas

Una pieza creada por fusión puede tocar a otra igual y fusionarse a su vez.
No hay límite de cascada ni lógica especial por nivel: la cascada surge sola
porque la nueva pieza vuelve al flujo normal de física y contactos.

En la primera versión no hay bonificación por cascada.

---

## 11. Orden y consistencia

- Una pieza nunca participa en dos fusiones. Garantía: el paso a `CONSUMED`
  ocurre en el mismo instante en que se acepta el contacto, antes de cualquier
  otro.
- Si A toca a B y a C (los tres iguales) en el mismo paso, gana el **primer
  contacto recibido**. C queda libre.
- Las fusiones pendientes de un mismo paso se resuelven en el orden en que se
  aceptaron.
- **Determinismo exigible:** ante la misma secuencia de eventos de contacto, la
  resolución es idéntica. No se exige determinismo de la física de Godot entre
  ejecuciones, porque el motor no lo garantiza.

---

## 12. Peligro y Game Over

La **línea de peligro** está a `danger_line_y` (100 px) del borde superior.

**Regla:** si alguna pieza en estado `ACTIVE` tiene **cualquier parte** por
encima de la línea durante `game_over_delay` (1.0 s) **seguidos**, la partida
pasa a `GAME_OVER`.

- El contador es por pieza y se reinicia en cuanto esa pieza queda
  completamente por debajo de la línea.
- Las piezas `DROPPING` y `CONSUMED` no cuentan.
- Mientras alguna pieza esté contando, la presentación muestra una advertencia
  (la línea parpadea con intensidad proporcional al tiempo acumulado).

---

## 13. Fin de partida (Game Over y Victoria)

Al entrar en `GAME_OVER` o en `VICTORY`:

- se ignoran las órdenes de soltado;
- se ignoran los contactos (ya no hay fusiones ni puntos);
- las piezas quedan **congeladas** en su sitio y siguen visibles;
- se cancelan las fusiones pendientes;
- la UI muestra la pantalla correspondiente con la puntuación final y la
  opción de reiniciar.

**Victoria:** animación de celebración en el punto de la fusión final
(destello, partículas y brillo máximo) y después la pantalla de victoria.

---

## 14. Reinicio

Disponible desde `GAME_OVER` y `VICTORY` (botón o tecla `R`):

1. se cancelan las fusiones pendientes y los contadores de peligro;
2. se eliminan todas las piezas;
3. se reinicia el estado lógico (puntuación 0, cola vacía, `READY`);
4. se generan ACTUAL y PRÓXIMO;
5. se descongela la simulación;
6. el estado pasa a `PLAYING`.

Se reutilizan los mismos recursos. Ninguna pieza ni fusión diferida de la
partida anterior puede aparecer en la nueva.

---

## 15. Estados de la partida

```text
           start()
  READY ─────────────→ PLAYING ──── peligro ────→ GAME_OVER
    ↑                     │                           │
    │                     └── fusión nivel máx ──→ VICTORY
    │                                                 │
    └──────────────── reset() ←───────────────────────┘
```

| Estado      | Soltar | Fusiones | Física     |
| ----------- | ------ | -------- | ---------- |
| `READY`     | No     | No       | —          |
| `PLAYING`   | Sí     | Sí       | Activa     |
| `GAME_OVER` | No     | No       | Congelada  |
| `VICTORY`   | No     | No       | Congelada  |

`READY` es transitorio: dura desde que se crea o reinicia la partida hasta que
`Main` llama a `start()`. Queda disponible para una futura pantalla de título.

---

## 16. Fuera del alcance de la primera versión

- Bonificaciones por cascada y multiplicadores.
- Récords persistentes.
- Logros (candidato: "Magnum Opus" por la primera victoria; fase opcional
  del plan).
- Audio.
- Física distinta por material.
- Arte definitivo (la primera versión usa placeholders: círculos de color con
  brillo).

---

## 17. Criterios de aceptación

| #  | Prueba         | Criterio                                                                                   |
| -- | -------------- | ------------------------------------------------------------------------------------------ |
| 1  | Colocación     | El jugador apunta y suelta; la pieza aparece en `(clamp(x), spawn_y)`, nunca dentro de una pared |
| 2  | Cooldown       | Una segunda orden de soltado durante el cooldown se ignora                                 |
| 3  | Física         | La pieza cae y choca con las paredes, el suelo y otras piezas                              |
| 4  | Fusión         | Dos piezas iguales en contacto producen exactamente una pieza del siguiente nivel          |
| 5  | No fusión      | Dos piezas de niveles distintos no se fusionan                                             |
| 6  | Consumo        | Una pieza consumida no participa en una segunda fusión                                     |
| 7  | Cascada        | Una pieza creada por fusión puede fusionarse a continuación                                |
| 8  | Puntuación     | Cada fusión suma el `score_value` de la pieza creada                                       |
| 9  | Cola           | Tras soltar, PRÓXIMO pasa a ser ACTUAL y se genera uno nuevo                               |
| 10 | Generación     | Cambiar `spawn_strategy` cambia la distribución sin tocar código                           |
| 11 | Exención       | Una pieza recién soltada que cruza la línea no provoca Game Over                           |
| 12 | Game Over      | Una pieza `ACTIVE` sobre la línea durante 1 s provoca Game Over y bloquea las soltadas     |
| 13 | Victoria       | Dos piezas de nivel máximo en contacto producen `VICTORY` y el bonus                       |
| 14 | Reinicio       | Reiniciar deja el tablero vacío, la puntuación en 0 y ninguna fusión fantasma              |
