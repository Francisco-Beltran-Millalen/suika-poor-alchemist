# Diseño general del juego

## 1. Concepto

El juego es un puzzle de física inspirado en **Suika Game**.

El jugador debe dejar caer objetos dentro de un recipiente y combinarlos
para crear objetos progresivamente más grandes. Dos objetos del mismo
tipo, al entrar en contacto, se fusionan y generan el siguiente objeto
de la cadena.

El objetivo general es conseguir la combinación final, una **sandía**,
mientras se intenta mantener el recipiente ordenado y evitar que los
objetos alcancen la zona de peligro.

## 2. Bucle principal

La partida sigue un ciclo sencillo:

1.  El juego muestra el próximo objeto que puede colocar el jugador.
2.  El jugador decide dónde dejarlo caer.
3.  El objeto cae y se comporta mediante física.
4.  Los objetos pueden desplazarse, rebotar y acomodarse dentro del
    recipiente.
5.  Cuando dos objetos compatibles entran en contacto, se fusionan.
6.  La fusión crea un objeto de nivel superior.
7.  El jugador continúa colocando objetos.
8.  La partida termina cuando los objetos alcanzan la condición de
    derrota.

El desafío surge de tomar decisiones sobre dónde colocar cada objeto y
de prever cómo afectará la física a los objetos que ya están dentro del
recipiente.

## 3. Sistema de combinación

Cada objeto pertenece a un nivel dentro de una cadena de progresión.

Dos objetos del mismo nivel pueden combinarse para producir un objeto
del nivel siguiente:

**Objeto + Objeto → Objeto siguiente**

La cadena concreta de objetos todavía queda por definir.

La combinación final de la cadena será la **sandía**.

## 4. Papel de la física

La física es una parte fundamental del juego y no solamente una
representación visual.

Los objetos deben poder:

-   caer por gravedad;
-   chocar entre sí;
-   rebotar;
-   rodar;
-   desplazarse después de una combinación;
-   acomodarse dentro del recipiente.

Por lo tanto, las decisiones del jugador deben considerar tanto la
posición inicial del objeto como el comportamiento posterior de los
objetos afectados por la física.

## 5. Condición de derrota

El recipiente tendrá una zona o límite que determinará cuándo los
objetos han ocupado demasiado espacio.

La condición exacta de derrota todavía queda por definir.

## 6. Alcance inicial

El objetivo inicial es construir una versión pequeña y funcional que
contenga únicamente los elementos fundamentales:

-   recipiente;
-   objetos con física;
-   colocación y caída;
-   combinación entre objetos iguales;
-   progresión hacia objetos mayores;
-   puntuación;
-   condición de derrota;
-   reinicio de partida.

Los detalles visuales, efectos, audio, balance y otras características
secundarias se definirán posteriormente.
