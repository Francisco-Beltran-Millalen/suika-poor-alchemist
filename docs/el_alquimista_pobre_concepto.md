# El Alquimista Pobre

## Concepto

**El Alquimista Pobre** es un juego en el que el protagonista es un
alquimista chatarrero que intenta producir materiales cada vez más
valiosos a partir de basura y materiales de poco valor.

El alquimista posee un artefacto especial capaz de transformar y
fusionar materiales, permitiéndole convertir objetos baratos en
elementos progresivamente más valiosos.

## Progresión de valor

La idea central es que cada nivel de material debe comunicar claramente
un aumento de valor.

La progresión no consiste solamente en cambiar de objeto, sino en
mostrar visualmente que el material obtenido es cada vez más raro,
valioso y difícil de conseguir.

La progresión conceptual va desde:

**basura → material común → material refinado → material valioso →
material raro → material muy raro → material excepcional → material
legendario**

Y se concreta en esta cadena de ocho materiales (referencia visual:
`El Alquimista Pobre_ De Basura a Leyenda.png`):

| Nivel | Material           | Rareza     | Descripción                          |
| ----- | ------------------ | ---------- | ------------------------------------ |
| 1     | Basura             | Común      | Objetos inútiles y desechos comunes. |
| 2     | Metal común        | Común      | Fragmentos de metal sin refinar.     |
| 3     | Cobre              | Poco común | Metal básico y útil.                 |
| 4     | Plata              | Raro       | Metal refinado y valioso.            |
| 5     | Oro                | Muy raro   | Metal precioso de gran valor.        |
| 6     | Oro encantado      | Épico      | Oro con propiedades mágicas.         |
| 7     | Material celestial | Épico+     | Sustancia extremadamente rara y poderosa. |
| 8     | Piedra Filosofal   | Legendario | Material legendario de gran poder alquímico. |

Los datos de juego de cada material están en `03_data_design.md` §4.

## Cómo comunicar el valor

El valor debe poder reconocerse visualmente sin necesidad de conocer
previamente cada material.

Se utilizará una combinación de elementos visuales:

-   Los materiales más comunes tendrán una apariencia simple, opaca y
    poco llamativa.
-   A medida que aumente su rareza, los materiales serán más refinados y
    visualmente especiales.
-   Los materiales raros comenzarán a emitir brillo.
-   Mientras más raro sea un objeto, más intenso y evidente será su
    brillo.
-   Los materiales de mayor valor podrán presentar efectos de luz o
    energía que los distingan claramente de los niveles inferiores.

También se considera necesario utilizar una **leyenda de rareza o
valor**, de manera que exista una referencia visual explícita para
entender qué tan valioso es cada material.

## Fantasía del juego

La fantasía principal es la de un **alquimista pobre y chatarrero** que
empieza trabajando con basura y materiales sin valor, pero utiliza su
artefacto para transformar progresivamente esos materiales hasta
alcanzar sustancias extraordinariamente valiosas.

El objetivo final es la **Piedra Filosofal**: la partida se gana al fusionar
dos de ellas.

## Dirección visual pendiente

Todavía no se ha definido el estilo artístico definitivo. La imagen de
referencia (materiales facetados de aspecto *low-poly* pintado, taller de
madera cálido) es la dirección provisional. La primera versión usa
placeholders: círculos de color con brillo creciente.

Lo que sí queda establecido es que la representación visual debe
priorizar la **lectura de la progresión de valor**: el jugador debe
poder distinguir intuitivamente un material barato de uno raro y uno
raro de uno legendario.
