# Diseño general del juego

## 1. Concepto

**El Alquimista Pobre** es un puzzle de física inspirado en **Suika Game**.

El jugador deja caer materiales dentro de un recipiente alquímico. Cuando dos
materiales iguales se tocan, se transmutan en el siguiente material de la
cadena, más grande y más valioso.

La meta es fusionar **dos Piedras Filosofales**, sin que el recipiente se
llene por encima de la línea de peligro.

La fantasía y la dirección visual están en `el_alquimista_pobre_concepto.md`.

## 2. Bucle principal

1. El juego muestra el material actual y el próximo.
2. El jugador elige la posición horizontal y lo suelta.
3. El material cae y se comporta según la física.
4. Los materiales se desplazan, ruedan y se acomodan.
5. Dos materiales iguales en contacto se fusionan en el siguiente nivel.
6. Las fusiones pueden encadenarse en cascada y suman puntos.
7. Tras un breve cooldown, el jugador suelta el siguiente material.

El juego es continuo: la física y las fusiones no esperan al jugador.

## 3. Cadena de materiales

```text
1 Basura → 2 Metal común → 3 Cobre → 4 Plata → 5 Oro
  → 6 Oro encantado → 7 Material celestial → 8 Piedra Filosofal
```

Valores, tamaños y rarezas: `03_data_design.md` §4.

## 4. Papel de la física

La física es parte del desafío, no solo una representación. Los materiales
caen, chocan, rebotan, ruedan y se desplazan después de una fusión. El
jugador tiene que prever tanto dónde cae su material como cómo afectará a los
que ya están en el recipiente.

## 5. Fin de partida

- **Derrota:** un material asentado permanece por encima de la línea de
  peligro durante 1 segundo.
- **Victoria:** dos Piedras Filosofales se fusionan.

Reglas exactas: `04_gameplay_design.md` §9.1 y §12.

## 6. Alcance de la primera versión

- Recipiente con paredes y línea de peligro.
- Materiales con física.
- Apuntado, soltado y cooldown.
- Fusión, cascadas y puntuación.
- Generación intercambiable del próximo material (tres estrategias).
- Derrota, victoria con animación y reinicio.
- Visuales placeholder legibles (círculos de color con brillo según rareza) y
  leyenda de rareza.

Quedan para después: arte definitivo, audio, logros, récords y balance fino.
