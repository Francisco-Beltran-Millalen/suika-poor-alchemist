# Diseño de datos

## 1. Objetivo

Este documento define los datos configurables de Suika para la primera
implementación.

El documento debe permitir crear los `Resource` y escenas de datos
necesarios sin volver a decidir su estructura durante la implementación.

La arquitectura general ya está definida en `02_technical_design.md`.
Aquí solamente se define **qué datos existen y cuáles son sus valores o
reglas**.

------------------------------------------------------------------------

# 2. PieceData

Cada tipo de fruta será un `Resource` de tipo `PieceData`.

``` text
PieceData
├── id
├── level
├── visual
├── collision_shape
├── next_piece
└── score_value
```

## 2.1. Campos

  Campo               Tipo                 Inspector Regla
  ------------------- ------------------ ----------- ---------------------------------------
  `id`                `StringName`                Sí Identificador único
  `level`             `int`                       Sí Nivel de progresión
  `visual`            recurso visual              Sí Representación de la fruta
  `collision_shape`   recurso de forma            Sí Forma física
  `next_piece`        `PieceData`                 Sí Resultado de una combinación
  `score_value`       `int`                       Sí Puntos otorgados por crear esta fruta

No se almacenará estado mutable en `PieceData`.

------------------------------------------------------------------------

# 3. Cadena de frutas

La primera versión utilizará una cadena de ocho niveles:

``` text
1  Cerezas
↓
2  Fresa
↓
3  Uva
↓
4  Naranja
↓
5  Manzana
↓
6  Pera
↓
7  Melocotón
↓
8  Sandía
```

La regla es siempre:

``` text
2 frutas iguales → 1 fruta del nivel siguiente
```

La sandía es el último nivel.

Por lo tanto:

``` text
watermelon.next_piece = null
```

No existe combinación posterior a la sandía.

Los identificadores serán:

``` text
cherry
strawberry
grape
orange
apple
pear
peach
watermelon
```

------------------------------------------------------------------------

# 4. Recursos `.tres`

Los recursos de fruta serán:

``` text
res://piece/data/
├── cherry.tres
├── strawberry.tres
├── grape.tres
├── orange.tres
├── apple.tres
├── pear.tres
├── peach.tres
└── watermelon.tres
```

Cada recurso tendrá su propio `PieceData`.

Ejemplo conceptual:

``` text
cherry.tres
    id = cherry
    level = 1
    next_piece = strawberry.tres
    score_value = 1
```

------------------------------------------------------------------------

# 5. Puntuación

La puntuación se obtiene al crear la nueva fruta mediante una
combinación.

Los valores iniciales serán:

    Nivel Fruta         Puntos
  ------- ----------- --------
        1 Cerezas            1
        2 Fresa              3
        3 Uva                6
        4 Naranja           10
        5 Manzana           15
        6 Pera              21
        7 Melocotón         28
        8 Sandía            36

La progresión utiliza:

``` text
score(level) = level × (level + 1) / 2
```

Esto hace que una combinación de nivel superior tenga un valor creciente
sin necesitar una tabla de lógica especial.

`score_value` describe el valor de crear esa fruta.

La puntuación acumulada continúa perteneciendo a `GameState`.

------------------------------------------------------------------------

# 6. GameConfig

`GameConfig` será un `Resource` con la configuración global de la
partida.

La primera versión tendrá:

``` text
GameConfig
├── container_width
├── container_height
├── danger_height
├── spawn_height
├── spawn_margin
├── game_over_delay
└── initial_state
```

## 6.1. Valores iniciales

  Campo                  Valor inicial Unidad
  -------------------- --------------- ----------------------------
  `container_width`                480 px
  `container_height`               720 px
  `danger_height`                  120 px desde el fondo
  `spawn_height`                    60 px desde el borde superior
  `spawn_margin`                    24 px
  `game_over_delay`                1.0 segundos
  `initial_state`            `PLAYING` estado

Estos valores son la configuración inicial de la primera versión y
podrán ajustarse durante las pruebas de balance.

------------------------------------------------------------------------

# 7. Archivo GameConfig

La configuración global se almacenará en:

``` text
res://game/game_config.tres
```

La escena principal utilizará este recurso como fuente de configuración.

No se crearán copias independientes de estos valores en distintos
sistemas.

La fuente de verdad será:

``` text
game_config.tres
```

------------------------------------------------------------------------

# 8. Parámetros que NO pertenecen a GameConfig

No se introducirán en `GameConfig` parámetros que ya pertenezcan
claramente a una pieza.

Por ejemplo:

``` text
masa
fricción
rebote
radio
```

no se definirán globalmente si dependen de cada fruta.

Esos valores deberán pertenecer a `PieceData` si resultan necesarios
para el balance físico.

Para la primera implementación, sin embargo, la física común de las
piezas se mantendrá fuera de `PieceData` hasta que las pruebas
demuestren que las frutas necesitan valores físicos diferentes.

------------------------------------------------------------------------

# 9. Física de las piezas

La primera versión utilizará física común para todos los tipos de fruta.

Por lo tanto, `PieceData` **no** tendrá inicialmente:

``` text
mass
friction
bounce
gravity_scale
```

La razón es evitar convertir diferencias físicas hipotéticas en
configuración antes de saber que son necesarias.

La diferencia entre frutas estará inicialmente determinada por:

-   tamaño;
-   forma de colisión;
-   nivel;
-   cadena;
-   puntuación.

Los parámetros físicos comunes serán responsabilidad de la escena
`Piece` y su configuración física.

------------------------------------------------------------------------

# 10. Tamaño de las frutas

El tamaño visual y físico de cada fruta será parte de su definición de
pieza.

La escala exacta de cada recurso deberá mantener una progresión clara:

``` text
nivel superior
    ↓
mayor tamaño
```

No se permitirá que una fruta de nivel superior sea físicamente menor
que una de nivel inferior sin una decisión explícita de diseño.

El radio o escala exacta deberá quedar definido junto con los recursos
visuales y de colisión de cada fruta.

------------------------------------------------------------------------

# 11. Regla de consistencia de PieceData

Cada `PieceData` debe cumplir:

``` text
id único
level único
next_piece coherente
visual válido
collision_shape válida
score_value válido
```

Además:

``` text
level 1 → next_piece = level 2
level 2 → next_piece = level 3
...
level 7 → next_piece = level 8
level 8 → next_piece = null
```

No se permitirán ciclos:

``` text
A → B → C → A
```

ni saltos:

``` text
A(level 1) → C(level 3)
```

La cadena debe avanzar exactamente un nivel.

------------------------------------------------------------------------

# 12. Validación de datos

Los Resources deben poder validarse antes de ejecutar una partida.

La validación debe detectar como mínimo:

-   `id` vacío;
-   `id` duplicado;
-   `level` duplicado;
-   `next_piece` ausente antes de la sandía;
-   `next_piece` incorrecto;
-   `next_piece` apuntando a sí mismo;
-   ciclo en la cadena;
-   `score_value` negativo;
-   visual inexistente;
-   forma de colisión inexistente.

El objetivo es que un error de configuración produzca un error
identificable de datos y no un fallo inesperado durante una combinación.

------------------------------------------------------------------------

# 13. Inspector

El Inspector será utilizado para modificar datos de diseño.

### PieceData

Debe exponer:

``` text
Identity
├── id
└── level

Progression
└── next_piece

Presentation
└── visual

Physics
└── collision_shape

Scoring
└── score_value
```

### GameConfig

Debe exponer:

``` text
Board
├── container_width
├── container_height
└── danger_height

Spawn
├── spawn_height
└── spawn_margin

Game
├── game_over_delay
└── initial_state
```

El Inspector no será utilizado como mecanismo para editar el estado de
una partida en ejecución.

------------------------------------------------------------------------

# 14. Estado versus configuración

La regla definitiva es:

``` text
PieceData
    configuración de un tipo de fruta

GameConfig
    configuración global

Piece
    estado físico de una instancia

GameState
    estado lógico de una partida
```

Por ejemplo:

``` text
score_value = 15
```

es configuración.

Mientras:

``` text
score = 327
```

es estado.

Del mismo modo:

``` text
collision_shape
```

es configuración.

Mientras:

``` text
position
velocity
rotation
```

son estado de una instancia.

------------------------------------------------------------------------

# 15. Qué NO se agregará a los Resources

No se almacenarán en `PieceData` funciones o referencias destinadas a
ejecutar reglas de juego.

No se agregará:

``` text
merge()
add_score()
game_over()
spawn()
```

Los Resources contienen datos.

Las reglas continúan perteneciendo a la simulación definida en
`02_technical_design.md`.

------------------------------------------------------------------------

# 16. Revisión adversaria

El diseño se considera defectuoso si aparece cualquiera de los
siguientes problemas.

## 16.1. `PieceData` se convierte en un God Object

Síntoma:

``` text
PieceData
├── merge()
├── spawn()
├── add_score()
├── game_over()
└── ...
```

Problema:

El recurso deja de ser datos y comienza a contener lógica de simulación.

Corrección:

Mantener `PieceData` como definición de configuración.

------------------------------------------------------------------------

## 16.2. `GameConfig` comienza a almacenar estado

Síntoma:

``` text
GameConfig.score
GameConfig.current_piece
GameConfig.game_over
```

Problema:

Un recurso compartido puede terminar transportando estado entre
partidas.

Corrección:

El estado permanece en `GameState`.

------------------------------------------------------------------------

## 16.3. Dos fuentes de verdad para la cadena

Síntoma:

``` text
PieceData.next_piece
```

y además:

``` text
MergeSystem
    if level == 1: ...
    if level == 2: ...
```

Problema:

La cadena está duplicada.

Corrección:

`next_piece` es la fuente de verdad de la progresión.

------------------------------------------------------------------------

## 16.4. La puntuación se duplica

Síntoma:

``` text
PieceData.score_value
```

pero `MergeSystem` mantiene además una tabla independiente de
puntuación.

Problema:

Los dos sistemas pueden quedar desincronizados.

Corrección:

El valor de creación de una pieza pertenece a `PieceData`.

------------------------------------------------------------------------

## 16.5. Se agregan parámetros porque "podrían ser útiles"

Síntoma:

``` text
PieceData
├── mass
├── friction
├── bounce
├── gravity
├── density
├── air_resistance
└── ...
```

sin que exista una necesidad de diseño.

Problema:

El Inspector se llena de parámetros que aumentan la complejidad sin
aportar control real.

Corrección:

Agregar un dato solamente cuando tenga una responsabilidad clara y sea
necesario para el diseño o balance.

------------------------------------------------------------------------

## 16.6. Configuración duplicada

Síntoma:

``` text
GameConfig.container_width
Board.container_width
DropSystem.container_width
```

Problema:

No existe una fuente de verdad clara.

Corrección:

La configuración global debe provenir de `GameConfig`.

------------------------------------------------------------------------

## 16.7. Recursos mutables

Síntoma:

``` text
piece.data.score_value = ...
```

durante una partida.

Problema:

Varias instancias pueden compartir el mismo recurso.

Corrección:

Los Resources se consideran configuración inmutable durante la
ejecución.

------------------------------------------------------------------------

## 16.8. La cadena contiene inconsistencias

Síntoma:

``` text
apple.level = 5
apple.next_piece.level = 7
```

Problema:

Se rompe la progresión definida.

Corrección:

`next_piece.level` debe ser siempre `level + 1`.

------------------------------------------------------------------------

## 16.9. La sandía tiene siguiente pieza

Síntoma:

``` text
watermelon.next_piece != null
```

Problema:

La cadena no tiene un final válido.

Corrección:

La sandía es el nivel máximo y `next_piece` debe ser `null`.

------------------------------------------------------------------------

## 16.10. El Inspector se convierte en una API interna

Síntoma:

Variables privadas se hacen públicas solamente para poder modificarlas
manualmente.

Problema:

Se pierde la distinción entre configuración y estado.

Corrección:

Exponer únicamente parámetros de diseño.

------------------------------------------------------------------------

# 17. Pruebas de diseño

Antes de considerar terminado el sistema de datos deben cumplirse estas
pruebas:

### Prueba 1

Crear una fruta nueva requiere crear/configurar un `PieceData`, no
escribir una nueva clase.

**Debe ser sí.**

### Prueba 2

Cambiar la siguiente fruta requiere modificar `next_piece`, no
`MergeSystem`.

**Debe ser sí.**

### Prueba 3

Cambiar la puntuación requiere modificar `score_value`, no la lógica de
combinación.

**Debe ser sí.**

### Prueba 4

Crear una nueva partida reutiliza los mismos Resources sin conservar el
estado de la partida anterior.

**Debe ser sí.**

### Prueba 5

Un `PieceData` compartido por diez piezas no provoca que las piezas
compartan posición, velocidad o estado.

**Debe ser sí.**

### Prueba 6

Un recurso mal configurado puede detectarse antes de depender de una
combinación durante la partida.

**Debe ser sí.**

### Prueba 7

Modificar `GameConfig` no requiere modificar `DropSystem`,
`DangerSystem` ni `GameState`.

**Debe ser sí.**

------------------------------------------------------------------------

# 18. Decisión final

La primera versión de datos queda definida así:

``` text
PieceData
├── id
├── level
├── visual
├── collision_shape
├── next_piece
└── score_value
```

con ocho frutas:

``` text
Cerezas → Fresa → Uva → Naranja → Manzana → Pera → Melocotón → Sandía
```

y:

``` text
GameConfig
├── container_width = 480
├── container_height = 720
├── danger_height = 120
├── spawn_height = 60
├── spawn_margin = 24
├── game_over_delay = 1.0
└── initial_state = PLAYING
```

La puntuación inicial es:

``` text
1, 3, 6, 10, 15, 21, 28, 36
```

La configuración se almacena en Resources.

El estado mutable no.

La cadena de combinación se define mediante `next_piece`.

La arquitectura no contiene tablas paralelas de frutas, puntuación o
progresión.

Cualquier nuevo dato debe justificar su existencia antes de incorporarse
al modelo.
