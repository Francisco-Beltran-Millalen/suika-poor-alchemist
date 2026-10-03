# Diseño de Gameplay

## 1. Objetivo del documento

Este documento define las reglas jugables de la primera implementación de **El Alquimista Pobre**.

El objetivo es transformar el concepto general en reglas suficientemente precisas para que el juego pueda implementarse y probarse sin tener que tomar decisiones fundamentales durante la programación.

Este documento define el comportamiento del jugador, las piezas, las colocaciones, las fusiones, las cascadas, el flujo de partida y las condiciones básicas de puntuación y derrota.

No define la arquitectura de código, los recursos de Godot, el estilo artístico definitivo, los efectos audiovisuales ni el balance final.

---

# 2. Fantasía jugable

El jugador controla indirectamente a un alquimista chatarrero que utiliza un artefacto para transformar materiales baratos en materiales progresivamente más valiosos.

La acción principal consiste en **elegir dónde colocar un material y observar cómo la física y las fusiones transforman el contenido del recipiente**.

El jugador no controla directamente los objetos después de soltarlos.

Por lo tanto, el desafío principal consiste en:

- elegir una posición de colocación;
- anticipar cómo caerá el material;
- decidir qué agrupaciones conviene crear;
- mantener espacio disponible;
- aprovechar las fusiones;
- evitar que los materiales alcancen la zona de peligro.

---

# 3. Bucle de juego

Una partida sigue este ciclo:

1. El juego determina el material actual.
2. El jugador observa el material actual y el próximo material.
3. El jugador elige dónde colocarlo.
4. El jugador confirma la colocación.
5. El material cae dentro del recipiente.
6. La física resuelve su movimiento y las colisiones.
7. Se comprueban posibles fusiones.
8. Las fusiones producen materiales de nivel superior.
9. Los nuevos materiales vuelven a interactuar con la física.
10. Se resuelven posibles fusiones adicionales.
11. Se actualiza la puntuación.
12. El juego determina el siguiente material.
13. Se comprueba la condición de derrota.
14. Si la partida continúa, el jugador puede realizar la siguiente colocación.

El ciclo continúa hasta que se alcanza la condición de Game Over.

---

# 4. Control del jugador

La interacción principal será horizontal.

El jugador puede desplazar la posición de colocación del material actual a izquierda y derecha antes de soltarlo.

Conceptualmente:

```text
← mover posición de colocación →
             ↓
          soltar
             ↓
       material cae
```

El jugador no selecciona directamente una posición vertical.

La altura inicial del material está determinada por la configuración del tablero.

La posición horizontal es la principal decisión estratégica del jugador.

---

# 5. Colocación

Cuando el jugador confirma la colocación:

1. Se crea una nueva instancia física del material actual.
2. Se coloca en la posición horizontal seleccionada.
3. Se inicia su comportamiento físico.
4. El jugador deja de controlar directamente esa instancia.
5. El juego prepara el siguiente material.

La posición elegida debe respetar los límites del recipiente.

El material no puede ser colocado fuera del área válida del tablero.

---

# 6. Control durante la caída

Una vez soltado, el jugador no puede mover manualmente el material.

La pieza pasa completamente al control de la simulación física.

No existen, en la primera versión, mecanismos para:

- agarrar una pieza;
- detener una pieza;
- empujar manualmente una pieza;
- modificar su trayectoria después de soltarla.

La intención del jugador termina con la decisión de posición y la acción de soltar.

---

# 7. Física

La física es parte del desafío jugable.

Los materiales deben poder:

- caer;
- chocar;
- rebotar;
- rodar;
- desplazarse después de una colisión;
- desplazar otros materiales;
- acomodarse dentro del recipiente.

El comportamiento exacto de estas propiedades será definido posteriormente mediante el diseño de física y las pruebas de balance.

La regla de gameplay es que, después de la colocación, el resultado depende de la simulación física.

---

# 8. Piezas y niveles

Cada material pertenece a un nivel de progresión.

La primera versión utiliza ocho niveles:

```text
Nivel 1 → Nivel 2 → Nivel 3 → Nivel 4
       → Nivel 5 → Nivel 6 → Nivel 7 → Nivel 8
```

La cadena concreta de materiales definida actualmente es:

```text
Cerezas
↓
Fresa
↓
Uva
↓
Naranja
↓
Manzana
↓
Pera
↓
Melocotón
↓
Sandía
```

La cadena de datos ya establece que cada material tiene un siguiente material y que la sandía es el nivel final.

---

# 9. Regla de fusión

Dos piezas del mismo nivel pueden fusionarse.

La regla general es:

```text
material + material
        ↓
material del siguiente nivel
```

Ejemplo:

```text
Cereza + Cereza
        ↓
      Fresa
```

La fusión solamente es válida cuando las dos piezas pertenecen al mismo nivel y todavía están activas en la simulación.

Una pieza no puede fusionarse consigo misma.

Una pieza que ya fue consumida por una fusión no puede participar nuevamente en otra fusión.

---

# 10. Momento de la fusión

La fusión se produce como consecuencia del contacto físico entre piezas compatibles.

La física determina cuándo dos piezas entran en contacto.

El sistema de juego determina si ese contacto produce una fusión válida.

Conceptualmente:

```text
contacto físico
      ↓
¿mismo nivel?
      ↓
¿ambas piezas activas?
      ↓
      sí
      ↓
     fusión
```

El contacto por sí solo no modifica una pieza si las condiciones de combinación no se cumplen.

---

# 11. Resolución de una fusión

Cuando dos piezas compatibles se fusionan:

1. Las dos piezas originales dejan de participar en nuevas fusiones.
2. Se determina el material del siguiente nivel.
3. Se crea una nueva pieza de ese nivel.
4. La nueva pieza aparece en una posición derivada de las piezas fusionadas.
5. La nueva pieza entra inmediatamente en la simulación física.
6. Se otorgan los puntos correspondientes.
7. Se comprueba si la nueva pieza puede producir otra fusión.

La nueva pieza no es una entidad especial.

Se comporta como cualquier otra pieza del mismo nivel.

---

# 12. Posición de la nueva pieza

La posición exacta de la pieza resultante se definirá durante la implementación de física.

La regla de gameplay es que la nueva pieza debe aparecer **en la zona de la combinación**, en lugar de aparecer en una posición arbitraria del tablero.

La intención es que la fusión tenga una consecuencia física observable.

La nueva pieza puede desplazarse inmediatamente debido a la gravedad, colisiones y otros efectos de la simulación.

---

# 13. Fusiones en cascada

Una fusión puede producir otra fusión.

Ejemplo conceptual:

```text
A + A → B

B ya se encuentra junto a otro B

B + B → C
```

La cadena puede continuar mientras existan combinaciones válidas.

No existe un límite artificial de niveles de cascada.

Las cascadas terminan cuando no quedan combinaciones válidas que puedan resolverse a partir de los movimientos producidos por la fusión.

---

# 14. Orden de resolución

La resolución de fusiones debe evitar que una misma pieza sea consumida dos veces.

Cuando una combinación es aceptada:

```text
A + B
```

ambas piezas quedan marcadas como consumidas antes de crear el resultado.

Esto evita situaciones como:

```text
A + B
B + C
```

donde B podría ser utilizada simultáneamente en dos fusiones.

La resolución debe producir un resultado determinista para un mismo estado de simulación.

---

# 15. Puntuación

La puntuación representa el valor producido por el alquimista.

La puntuación se obtiene cuando una fusión crea una nueva pieza.

El valor de cada nivel está definido actualmente como:

```text
Nivel 1   = 1
Nivel 2   = 3
Nivel 3   = 6
Nivel 4   = 10
Nivel 5   = 15
Nivel 6   = 21
Nivel 7   = 28
Nivel 8   = 36
```

La regla conceptual es:

```text
score(level) = level × (level + 1) / 2
```

Por ejemplo:

```text
Cereza + Cereza → Fresa
                         +3 puntos
```

La puntuación acumulada pertenece al estado de la partida.

---

# 16. Material actual y próximo material

El juego mantiene un material actual que el jugador puede colocar.

También muestra el próximo material.

Conceptualmente:

```text
ACTUAL
   ↓
jugador coloca
   ↓
PRÓXIMO pasa a ser ACTUAL
   ↓
se genera un nuevo PRÓXIMO
```

La regla exacta utilizada para generar los materiales futuros todavía no está definida en este documento.

La implementación deberá permitir definir posteriormente el sistema de generación sin modificar las reglas de fusión.

---

# 17. Fin de la colocación

Una colocación termina cuando el jugador suelta el material actual.

A partir de ese momento:

- el jugador pierde el control de esa pieza;
- la física toma el control;
- pueden producirse colisiones;
- pueden producirse fusiones;
- pueden producirse cascadas;
- el tablero se estabiliza progresivamente.

La siguiente colocación no debe producirse mientras el juego considere que la acción anterior todavía está siendo procesada, si la implementación requiere esperar a la resolución de física y fusiones.

El criterio exacto de estabilización será definido durante la implementación y pruebas.

---

# 18. Zona de peligro

El recipiente contiene una zona de peligro.

La zona de peligro representa el límite a partir del cual los materiales han ocupado demasiado espacio.

Su función es determinar cuándo la acumulación de materiales hace que la partida termine.

La configuración inicial ya define una altura de peligro dentro del recipiente.

La regla exacta de derrota todavía debe concretarse mediante pruebas de gameplay.

Por lo tanto, este documento establece la existencia de la zona, pero no fija todavía si basta con:

- tocarla;
- permanecer dentro de ella;
- permanecer dentro de ella durante cierto tiempo;
- u otra condición equivalente.

---

# 19. Game Over

Cuando se cumple la condición de derrota:

```text
partida
  ↓
GAME OVER
```

El jugador deja de poder realizar nuevas colocaciones.

Las acciones de input destinadas a crear nuevas piezas deben ignorarse.

La interfaz deberá informar que la partida terminó y permitir reiniciar.

La forma visual de comunicar Game Over pertenece al diseño de UI.

---

# 20. Reinicio

Al reiniciar:

1. Se eliminan las piezas de la partida anterior.
2. Se restablece el estado lógico.
3. Se restablece la puntuación.
4. Se genera el estado inicial de materiales.
5. El tablero queda vacío.
6. La partida vuelve al estado jugable.

El reinicio crea una nueva partida utilizando la misma configuración y los mismos datos.

No modifica los recursos de definición de materiales.

---

# 21. Estado de partida

A nivel de gameplay, la partida necesita distinguir como mínimo:

```text
READY
PLAYING
GAME_OVER
```

`READY` representa el estado previo al inicio de una partida.

`PLAYING` permite colocar materiales y procesar la simulación.

`GAME_OVER` bloquea nuevas acciones de colocación.

La implementación técnica ya define `GameState` como responsable de este estado.

---

# 22. Reglas de interacción fundamentales

La primera versión debe respetar estas reglas:

```text
1. El jugador elige una posición horizontal.
2. El jugador suelta un material.
3. El material cae mediante física.
4. El jugador no controla directamente la pieza después de soltarla.
5. Dos materiales iguales pueden fusionarse.
6. Una fusión crea el siguiente nivel.
7. Una pieza consumida no puede volver a fusionarse.
8. Una pieza nueva participa normalmente en la física.
9. Las fusiones pueden producir cascadas.
10. Las fusiones generan puntuación.
11. La acumulación puede provocar Game Over.
12. Game Over bloquea nuevas colocaciones.
13. Reiniciar crea una nueva partida.
```

Estas reglas constituyen el núcleo jugable de la primera versión.

---

# 23. Cosas que deliberadamente quedan fuera

Este documento no fija todavía:

- cadena temática definitiva de materiales de El Alquimista Pobre;
- sistema exacto de generación del próximo material;
- probabilidades de aparición;
- tamaños físicos definitivos;
- masa;
- fricción;
- rebote;
- gravedad;
- tolerancia exacta de contacto;
- criterio definitivo de estabilización;
- criterio definitivo de Game Over;
- bonificaciones por cascadas;
- multiplicadores;
- récords;
- efectos audiovisuales;
- animaciones;
- interfaz definitiva;
- balance de dificultad.

Estas decisiones deben diseñarse en documentos específicos o durante las pruebas correspondientes.

---

# 24. Criterios de aceptación del gameplay

El diseño de gameplay se considera correctamente implementado cuando:

### Prueba 1 — Colocación

El jugador puede seleccionar una posición horizontal válida y soltar el material.

### Prueba 2 — Física

El material cae y responde a las colisiones del recipiente y de otros materiales.

### Prueba 3 — Fusión

Dos materiales iguales pueden producir exactamente un material del siguiente nivel.

### Prueba 4 — No fusión

Dos materiales de niveles diferentes no se fusionan.

### Prueba 5 — Consumo

Una pieza consumida por una fusión no puede participar en una segunda fusión.

### Prueba 6 — Cascada

Una pieza creada por una fusión puede producir inmediatamente otra fusión válida.

### Prueba 7 — Puntuación

Cada fusión otorga el valor correspondiente al material creado.

### Prueba 8 — Próximo material

Después de una colocación, el material siguiente pasa correctamente a ser el material actual.

### Prueba 9 — Game Over

Cuando se cumple la condición de derrota definida para la implementación, no se permiten nuevas colocaciones.

### Prueba 10 — Reinicio

Reiniciar elimina correctamente el estado de la partida anterior y permite comenzar otra partida.

---

# 25. Decisión de diseño

La primera implementación de **El Alquimista Pobre** utilizará un modelo de juego deliberadamente simple:

```text
        elegir posición
              ↓
           soltar
              ↓
            física
              ↓
           contacto
              ↓
           ¿fusiona?
          ↙        ↘
        no          sí
        ↓            ↓
    continúa      siguiente
                     ↓
                  física
                     ↓
                posible cascada
                     ↓
                  puntuación
                     ↓
              comprobar derrota
                     ↓
                siguiente turno
```

El jugador toma decisiones discretas de colocación y la simulación física determina el resultado.

La profundidad del juego debe surgir de la interacción entre planificación espacial, acumulación de materiales y comportamiento emergente de las fusiones, no de añadir controles adicionales.

---

# 26. Estado del diseño

Con este documento quedan definidas las reglas fundamentales del bucle jugable.

Las decisiones que todavía requieren diseño específico son principalmente:

```text
Gameplay
├── reglas fundamentales        DEFINIDO
├── fusión                      DEFINIDO
├── cascadas                    DEFINIDO
├── puntuación básica           DEFINIDO
├── cadena de niveles           DEFINIDO
├── generación del próximo      PENDIENTE
├── física y balance            PENDIENTE
├── condición exacta de derrota PENDIENTE
├── progresión temática         PENDIENTE
└── UX / presentación           PENDIENTE
```

El siguiente diseño especializado debería abordar la **física y el balance**, porque esos parámetros determinarán gran parte de cómo se siente realmente el bucle definido aquí.
