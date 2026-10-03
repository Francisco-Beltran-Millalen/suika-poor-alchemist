# Diseño técnico

## 1. Objetivo

Este documento define la arquitectura técnica inicial de **Suika** en Godot.

El objetivo no es solamente dividir el código en scripts, sino establecer una arquitectura que mantenga separadas tres responsabilidades fundamentales:

```text
DATOS
  ↓
SIMULACIÓN
  ↓
PRESENTACIÓN
```

La dirección de las dependencias es deliberada:

- los datos no conocen la simulación;
- la simulación puede consumir datos, pero no conoce la presentación;
- la presentación observa el estado y los eventos de la simulación;
- ningún sistema de juego necesita conocer nodos de UI;
- ningún elemento visual debe contener reglas de juego.

Godot recomienda utilizar escenas y scripts aplicando responsabilidad única, encapsulación y bajo acoplamiento. También proporciona `Resource`, `RefCounted`, señales y escenas como mecanismos naturales para evitar convertir el árbol de nodos en un contenedor de toda la lógica. citeturn0search0turn0search4turn0search14

---

## 2. Principio fundamental: composición, no dependencia global

La escena principal será el **composition root** de la partida.

Su responsabilidad será ensamblar los componentes:

```text
Main
 ├── crea GameState
 ├── configura Simulation
 ├── configura Presentation
 └── conecta señales
```

`Main` puede conocer todos los niveles porque su función es precisamente ensamblarlos.

Los componentes internos, en cambio, deben conocer solamente las dependencias que necesitan.

No se utilizarán rutas globales como:

```text
get_node("/root/Main/...")
```

ni dependencias rígidas como:

```text
../../../../Main
```

Godot recomienda utilizar el árbol de escenas y señales para limitar el acoplamiento, y advierte que el estado global mediante Autoload puede hacer que los problemas se propaguen por todo el proyecto. citeturn0search6turn0search14

---

# 3. Capas

## 3.1. Capa de datos

Contiene información que describe el juego, pero no ejecuta la partida.

Ejemplos:

```text
PieceData
GameConfig
```

Puede utilizar `Resource` porque los recursos son serializables, reutilizables y editables desde el Inspector. citeturn0search4

Esta capa no debe:

- acceder al árbol de escenas;
- emitir órdenes a la simulación;
- acceder a la UI;
- contener referencias a nodos de una partida concreta.

---

## 3.2. Capa de simulación

Contiene el estado y comportamiento de una partida.

Ejemplos:

```text
GameState
Piece
DropSystem
MergeSystem
DangerSystem
```

Esta capa:

- consume datos;
- crea y modifica entidades físicas;
- aplica reglas;
- mantiene el estado de la partida;
- emite eventos.

No conoce:

- `Control`;
- `Label`;
- `TextureRect`;
- animaciones de UI;
- escenas de presentación.

---

## 3.3. Capa de presentación

Representa visualmente el estado de la simulación.

Ejemplos:

```text
GameUI
ScoreView
NextPieceView
GameOverView
```

Esta capa:

- observa eventos;
- muestra datos;
- envía acciones de entrada cuando corresponde.

No debe:

- calcular puntuación;
- decidir si una combinación es válida;
- decidir cuándo termina la partida;
- modificar directamente las piezas físicas.

---

# 4. Dirección de dependencias

La arquitectura debe respetar:

```text
             ┌─────────────┐
             │    DATOS    │
             └──────┬──────┘
                    ↓
             ┌─────────────┐
             │ SIMULACIÓN  │
             └──────┬──────┘
                    ↓
             ┌─────────────┐
             │PRESENTACIÓN │
             └─────────────┘
```

Nunca:

```text
Datos → Simulación
Datos → UI
Simulación → UI
```

La interpretación correcta de la flecha es "puede depender de".

Por lo tanto:

```text
PieceData
   ↑
 Piece
   ↑
MergeSystem
   ↑
GameState
   ↑
GameUI
```

La UI observa el resultado de la simulación, no controla cómo se produce.

---

# 5. Estructura de escenas

La estructura inicial será:

```text
main.tscn
└── Main
    ├── Simulation
    │   ├── Board
    │   │   ├── Container
    │   │   └── DangerZone
    │   └── Pieces
    │
    ├── Systems
    │   ├── DropSystem
    │   ├── MergeSystem
    │   └── DangerSystem
    │
    └── Presentation
        └── GameUI
```

Sin embargo, `Simulation` y `Systems` no deben convertirse en "carpetas de scripts" con responsabilidades ambiguas.

Su función es organizar el árbol.

Las responsabilidades reales pertenecen a los componentes concretos.

Godot utiliza escenas como unidades reutilizables y composables, por lo que una escena debe representar una entidad o composición coherente, no solamente servir como contenedor arbitrario. citeturn0search0turn0search8

---

# 6. Datos: PieceData

Cada tipo de pieza será descrito mediante un `Resource`.

```text
PieceData
├── id
├── level
├── visual
├── collision_shape
├── next_piece
└── score_value
```

`PieceData` describe qué es una pieza.

No describe una pieza concreta que ya está dentro del recipiente.

Por ejemplo:

```text
AppleData
AppleData
AppleData
```

pueden ser referencias al mismo recurso.

Mientras:

```text
Piece #1
Piece #2
Piece #3
```

son tres instancias físicas independientes.

Esto permite reutilizar datos sin duplicarlos.

---

# 7. Datos: GameConfig

Los parámetros globales configurables que no pertenecen a una pieza concreta pueden estar en otro `Resource`.

Conceptualmente:

```text
GameConfig
├── container_size
├── danger_height
├── initial_state
└── otros parámetros de configuración
```

No se debe utilizar `GameConfig` para almacenar estado mutable de una partida.

La diferencia es:

```text
GameConfig = configuración
GameState  = estado actual
```

---

# 8. Estado de ejecución

`GameState` representa una partida concreta.

No será un `Node`.

Será un objeto ligero, por ejemplo derivado de `RefCounted`.

```text
GameState
├── score
├── current_piece_data
├── next_piece_data
└── status
```

Estados:

```text
READY
PLAYING
GAME_OVER
```

`GameState` puede emitir:

```text
score_changed
current_piece_changed
next_piece_changed
status_changed
```

No conoce nodos.

No instancia escenas.

No accede a física.

Su responsabilidad es almacenar y comunicar el estado lógico de la partida.

Godot recomienda utilizar objetos ligeros cuando una responsabilidad no necesita formar parte del árbol de nodos. `Resource` y `RefCounted` son precisamente alternativas a usar `Node` para todo. citeturn0search4

---

# 9. Entidad física: Piece

La pieza física será una escena reutilizable.

```text
piece.tscn
└── Piece (RigidBody2D)
    ├── CollisionShape2D
    └── Visual
```

`Piece` representa una instancia física de `PieceData`.

Conceptualmente:

```text
Piece
 ├── data: PieceData
 └── estado físico
```

Responsabilidades:

- existir dentro de la simulación física;
- mantener su `PieceData`;
- responder a la física;
- detectar contactos relevantes;
- informar eventos.

No debe:

- modificar `GameState`;
- acceder a UI;
- ejecutar la combinación;
- calcular puntuación;
- decidir Game Over.

`RigidBody2D` permite que el motor controle el movimiento y la respuesta física de la pieza. citeturn0search12

---

# 10. Comunicación de Piece

`Piece` no conocerá a `MergeSystem`.

En lugar de:

```text
Piece → MergeSystem
```

se utilizará:

```text
Piece
  │
  └── signal: contact_detected(other)
                     ↓
              sistema conectado
```

Las señales permiten que un objeto reaccione a otro sin establecer una referencia directa entre ambos. Esto reduce el acoplamiento. citeturn0search14

La conexión será realizada por la composición de la partida.

---

# 11. Sistema de combinación

`MergeSystem` pertenece a la simulación.

Responsabilidad única:

> Resolver combinaciones entre piezas.

No debe controlar:

- UI;
- input;
- puntuación visual;
- Game Over;
- generación de niveles.

Recibe eventos de contacto y determina:

```text
¿Son compatibles?
        ↓
¿Siguen activas?
        ↓
¿Alguna ya está siendo consumida?
        ↓
Sí → resolver una sola vez
```

---

# 12. Evitar doble combinación

Este es un requisito arquitectónico importante.

Una colisión puede ser observada desde ambos cuerpos:

```text
A → B
B → A
```

No se deben ejecutar dos fusiones.

`MergeSystem` debe mantener un conjunto temporal de piezas que están siendo consumidas:

```text
pending_merges
consumed_pieces
```

El algoritmo conceptual es:

```text
recibir A + B

si A o B ya están consumidas:
    ignorar

si no son compatibles:
    ignorar

marcar A y B como consumidas
programar resolución
```

De esta manera la autoridad sobre la combinación existe en un único lugar.

---

# 13. Resolución de combinación

La resolución modifica la simulación.

```text
A + B
 ↓
determinar PieceData.next_piece
 ↓
crear nueva Piece
 ↓
colocarla en posición de combinación
 ↓
actualizar GameState
 ↓
liberar A y B
```

Si la modificación del árbol ocurre durante una etapa en la que no debe realizarse directamente, se puede diferir mediante `call_deferred()`. Godot proporciona este mecanismo para ejecutar una llamada posteriormente, al finalizar el procesamiento actual. 

El objetivo es que el orden de modificación del árbol sea explícito y no dependa accidentalmente del orden de las señales de física.

---

# 14. Combinaciones en cascada

Una pieza recién creada vuelve a ser una entidad normal de la simulación.

No existe una función especial como:

```text
resolve_level_2_combo()
resolve_level_3_combo()
```

La nueva pieza simplemente vuelve a participar:

```text
Nueva Piece
     ↓
Physics
     ↓
contact_detected
     ↓
MergeSystem
```

Por lo tanto, la misma arquitectura funciona para cualquier cantidad de niveles.

---

# 15. DropSystem

`DropSystem` pertenece a la simulación.

Responsabilidad:

> Convertir una orden de colocación en una nueva pieza física.

Entrada:

```text
drop_requested(position)
```

Proceso:

```text
GameState.next_piece
        ↓
crear Piece
        ↓
asignar PieceData
        ↓
colocar posición
        ↓
añadir a Pieces
        ↓
actualizar GameState
```

No debe saber cómo se dibuja la UI.

Tampoco debe decidir qué pieza será la siguiente mediante lógica propia si `GameState` es la fuente de verdad.

---

# 16. Input

El input debe considerarse una fuente de comandos, no una regla del juego.

Conceptualmente:

```text
Input
  ↓
drop_requested(position)
  ↓
DropSystem
```

La lógica de input puede vivir en un nodo/controlador específico o en la capa de presentación dependiendo de cómo se implemente la interfaz.

La regla arquitectónica es:

```text
input = intención
simulation = decisión y ejecución
```

Por ejemplo, el input puede decir:

```text
"quiero colocar en X = 320"
```

pero no:

```text
"crea una fruta nivel 3 y suma 30 puntos"
```

---

# 17. Board

El tablero pertenece a la simulación física.

```text
Board
├── Container
│   ├── LeftWall
│   ├── RightWall
│   └── Floor
└── DangerZone
```

Responsabilidades:

- definir los límites;
- contener físicamente las piezas;
- proporcionar la zona de detección necesaria.

No controla puntuación ni combinaciones.

---

# 18. DangerSystem

La detección física y la regla de derrota deben estar separadas.

```text
DangerZone
    ↓
body_entered
    ↓
DangerSystem
    ↓
GameState
```

`DangerZone` solamente detecta.

`DangerSystem` interpreta el evento según la regla de juego.

`GameState` cambia a `GAME_OVER`.

Esto permite modificar posteriormente la regla de derrota sin modificar la escena física.

---

# 19. Puntuación

La puntuación se modifica desde la simulación.

```text
MergeSystem
    ↓
GameState.add_score()
    ↓
score_changed
    ↓
GameUI
```

Nunca:

```text
MergeSystem → Label
```

ni:

```text
GameUI → GameState.score += 100
```

La UI solo representa el estado.

---

# 20. Presentación

La presentación será una escena independiente:

```text
game_ui.tscn
└── GameUI
    ├── ScoreView
    ├── NextPieceView
    └── GameOverView
```

`GameUI` recibe eventos:

```text
score_changed
next_piece_changed
status_changed
```

y actualiza sus elementos visuales.

No necesita conocer:

- `MergeSystem`;
- `DropSystem`;
- `Piece`;
- `DangerZone`.

Esto permite reemplazar completamente la interfaz sin modificar las reglas de juego.

---

# 21. Flujo de información

El flujo normal será:

```text
                 ┌──────────────┐
                 │  PieceData   │
                 └──────┬───────┘
                        ↓
Input → DropSystem → Piece
                        ↓
                   Physics
                        ↓
                MergeSystem
                        ↓
                   GameState
                        ↓
                    Signals
                        ↓
                    GameUI
```

La información viaja hacia la presentación.

Las reglas no viajan hacia la presentación.

---

# 22. Flujo de una combinación

```text
Physics
   ↓
Piece.contact_detected()
   ↓
MergeSystem
   ↓
validación
   ↓
marcar A/B como consumidas
   ↓
crear nueva Piece
   ↓
actualizar GameState
   ↓
score_changed
   ↓
GameUI
```

La UI no participa en ningún punto de la resolución.

---

# 23. Flujo de Game Over

```text
Physics
   ↓
DangerZone.body_entered
   ↓
DangerSystem
   ↓
GameState.set_game_over()
   ↓
status_changed
   ↓
GameUI
```

`DropSystem` también observa el estado y deja de aceptar órdenes mientras el estado sea `GAME_OVER`.

---

# 24. Flujo de reinicio

```text
GameUI
   ↓
restart_requested
   ↓
Main / GameSession
   ↓
reset GameState
   ↓
limpiar Pieces
   ↓
generar próximo estado
   ↓
PLAYING
   ↓
GameUI
```

La interfaz solicita reiniciar.

La interfaz no limpia el árbol.

La interfaz no crea piezas.

La interfaz no modifica directamente `GameState`.

---

# 25. Papel de Main

`Main` debe ser deliberadamente pequeño.

Su responsabilidad es:

```text
crear
conectar
inicializar
reiniciar
```

No debe contener:

- reglas de combinación;
- reglas de puntuación;
- lógica de física;
- lógica de UI;
- reglas de Game Over.

Si `main.gd` comienza a crecer significativamente, eso será una señal de que alguna responsabilidad debe trasladarse al sistema correspondiente.

---

# 26. Dependencias permitidas

```text
PieceData
   ↓
Piece

PieceData
   ↓
DropSystem

GameState
   ↑
DropSystem
MergeSystem
DangerSystem

GameState
   ↓
GameUI

Main
 ├── PieceData
 ├── GameState
 ├── DropSystem
 ├── MergeSystem
 ├── DangerSystem
 └── GameUI
```

La regla importante es que `Main` puede conocer a todos porque es el compositor.

Los componentes no deben conocer a `Main`.

---

# 27. Dependencias prohibidas

No se permitirá:

```text
Piece → GameUI
Piece → Main
Piece → MergeSystem
Piece → GameState
```

ni:

```text
GameUI → Piece
GameUI → MergeSystem
GameUI → DangerSystem
```

ni:

```text
PieceData → Node
PieceData → GameState
```

Esto mantiene las capas separadas.

---

# 28. ¿Qué ocurre si cambia la UI?

No debería ser necesario modificar la simulación.

Por ejemplo, cambiar:

```text
GameUI
```

por:

```text
MinimalGameUI
```

o:

```text
AnimatedGameUI
```

solo requiere conectar ambas a los mismos eventos de estado.

---

# 29. ¿Qué ocurre si cambia la cadena?

Modificar:

```text
PieceData.next_piece
```

no debe requerir modificar:

- `Piece`;
- `MergeSystem`;
- `DropSystem`;
- `GameState`;
- `GameUI`.

Esta es una prueba fundamental de reutilización.

---

# 30. ¿Qué ocurre si cambia la física?

Modificar:

```text
RigidBody2D
CollisionShape2D
PhysicsMaterial
```

no debería requerir modificar la lógica de puntuación ni la interfaz.

La física produce eventos.

Los sistemas interpretan esos eventos.

---

# 31. ¿Qué ocurre si cambia la condición de derrota?

Debe poder modificarse principalmente dentro de `DangerSystem`.

Por ejemplo, si posteriormente se decide que:

```text
una pieza debe permanecer sobre la línea durante cierto tiempo
```

no debería ser necesario modificar:

- `Piece`;
- `MergeSystem`;
- `GameUI`.

Esta separación es la razón de mantener `DangerZone` y `DangerSystem` separados.

---

# 32. Recursos compartidos y estado mutable

Un punto importante de Godot es que un `Resource` puede estar compartido por múltiples instancias.

Por ello:

```text
PieceData
```

debe tratarse como definición inmutable durante la partida.

No se debe hacer:

```text
piece.data.score_value += 10
```

si `score_value` pertenece al recurso compartido.

El estado mutable debe vivir en:

```text
Piece
GameState
```

según corresponda.

Los recursos describen.

Las instancias viven.

El estado cambia.

---

# 33. Estructura de archivos

La organización debe mantener los recursos relacionados cerca de sus escenas cuando resulte razonable, siguiendo las recomendaciones de organización de proyectos de Godot. Los nombres de archivos y carpetas utilizarán `snake_case`, mientras los nodos utilizarán `PascalCase`. citeturn0search3

Una estructura inicial:

```text
res://
├── game/
│   ├── main.tscn
│   ├── main.gd
│   ├── game_state.gd
│   └── game_config.tres
│
├── board/
│   ├── board.tscn
│   ├── board.gd
│   └── danger_zone.tscn
│
├── piece/
│   ├── piece.tscn
│   ├── piece.gd
│   └── piece_data.gd
│
├── systems/
│   ├── drop_system.gd
│   ├── merge_system.gd
│   └── danger_system.gd
│
├── ui/
│   ├── game_ui.tscn
│   └── game_ui.gd
│
└── assets/
```

La organización física de archivos puede evolucionar, pero la separación conceptual no debe perderse.

---

# 34. Prueba de desacoplamiento

Antes de considerar terminada esta arquitectura, debe poder responder afirmativamente a estas pruebas.

### Prueba 1 — UI

¿Podemos reemplazar completamente la UI sin modificar las reglas?

Debe ser sí.

### Prueba 2 — datos

¿Podemos agregar una nueva pieza modificando datos y recursos sin duplicar lógica?

Debe ser sí.

### Prueba 3 — física

¿Podemos modificar parámetros físicos sin tocar la puntuación?

Debe ser sí.

### Prueba 4 — combinación

¿Podemos cambiar la regla de combinación sin modificar la UI?

Debe ser sí.

### Prueba 5 — derrota

¿Podemos cambiar la condición de derrota sin modificar `Piece`?

Debe ser sí.

### Prueba 6 — reinicio

¿Podemos reiniciar una partida sin reconstruir la aplicación completa?

Debe ser sí.

### Prueba 7 — ejecución aislada

¿Puede `MergeSystem` funcionar sin instanciar la UI?

Debe ser sí.

### Prueba 8 — ausencia de globales

¿Puede una partida ejecutarse sin que `Piece` o `GameUI` necesiten un Autoload?

Debe ser sí.

---

# 35. Revisión adversaria

La arquitectura debe considerarse defectuosa si aparece cualquiera de estos síntomas.

### `Main` crece demasiado

Indica que se están acumulando responsabilidades.

### `Piece` empieza a conocer sistemas

Indica que la entidad física dejó de estar desacoplada.

### `GameUI` comienza a modificar reglas

Indica que la presentación está invadiendo la simulación.

### `GameState` empieza a instanciar nodos

Indica que el estado lógico está invadiendo la capa de escena.

### `PieceData` empieza a almacenar estado mutable

Indica que se está confundiendo definición con instancia.

### `MergeSystem` empieza a controlar puntuación, Game Over y input

Indica que el sistema de combinación se está convirtiendo en un God object.

### aparecen muchos Autoloads

Indica que se está utilizando estado global para evitar diseñar correctamente las dependencias.

---

# 36. Decisión arquitectónica

La arquitectura final para la primera implementación queda definida como:

```text
┌─────────────────────────────────────────┐
│              PRESENTACIÓN               │
│                                         │
│ GameUI                                   │
│   ↑                                      │
│   │ signals                              │
├───┼─────────────────────────────────────┤
│   │            SIMULACIÓN               │
│   │                                     │
│ GameState  DropSystem  MergeSystem       │
│     ↑          ↑          ↑              │
│     └──────────┴──────────┘              │
│                Piece                     │
│                  ↑                       │
│               Physics                    │
├──────────────────┼──────────────────────┤
│                  │                       │
│                DATOS                     │
│                  │                       │
│             PieceData                    │
│             GameConfig                   │
└─────────────────────────────────────────┘
```

`Main` queda fuera de estas capas como compositor:

```text
Main
 ├── construye
 ├── inyecta dependencias
 ├── conecta señales
 └── inicia / reinicia
```

No contiene reglas de dominio.

---

# 37. Elementos todavía no definidos

El diseño general todavía deja abiertos:

- cadena concreta de objetos;
- valores de puntuación definitivos;
- criterio exacto de derrota;
- parámetros físicos;
- presentación visual;
- efectos de sonido;
- balance;
- detalles finales de interfaz.

Estos elementos no deben inventarse dentro de este documento.

La arquitectura debe permitir incorporarlos posteriormente sin alterar la separación fundamental:

```text
Datos → Simulación → Presentación
```
