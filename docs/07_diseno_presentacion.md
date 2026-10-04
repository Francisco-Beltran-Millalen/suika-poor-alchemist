# Diseño de presentación

## 1. Objetivo

Reglas de la capa de presentación de **El Alquimista Pobre**: arte, escenario,
efectos, audio y pantallas. La arquitectura está en `02_technical_design.md`;
las reglas de juego, en `04_gameplay_design.md`. Este documento se amplía a
medida que la iteración 2 (`06_plan_iteracion_2.md`) añade presentación.

La presentación **observa** la simulación y nunca dicta reglas. Todo asset es
opcional: con `null` el juego usa el dibujo procedural o el silencio.

---

## 2. Orden de capas

De atrás hacia delante:

| # | Capa | Contenido |
| - | ---- | --------- |
| 1 | `Background` (`CanvasLayer` −1) | Fondo del taller, a pantalla completa |
| 2 | `World/Board/BackVisual` | Interior del frasco y línea de peligro |
| 3 | `World/Board/Pieces` | Piezas físicas |
| 4 | `World/Board/FrontVisual` | Paredes, suelo y reflejos del frasco |
| 5 | `World/DropPreview` | Pieza ACTUAL, línea guía y artefacto |
| 6 | `World/EffectsLayer` | Efectos de fusión, peligro y victoria |
| 7 | `GameUI` (`CanvasLayer`) | HUD y pantallas |

La línea de peligro va en la capa 2: las piezas la tapan, como en el juego
original.

### 2.1. Escenario (Anexo A.2)

- **Fondo.** `TextureRect` con `expand_mode = ignore size` y
  `stretch_mode = keep aspect covered`: el recorte "cubrir" deja el centro
  siempre visible y recorta los laterales según la ventana. El frasco ocupa
  el centro, así que ahí el fondo debe ser oscuro y con poco detalle. Sin
  textura, se ve el color de fondo del proyecto.
- **Frasco.** `BoardSkin` (`board/board_skin.tres`) agrupa `back_texture`
  (880×1200, interior a escala 2×), `front_texture` (1008×1264, exterior a
  escala 2×) y el color de la línea de peligro. `BackVisual` dibuja el interior
  en `(0, 0, W, H)`; `FrontVisual`, el exterior en `(−t, 0, W + 2t, H + t)`
  (`t = wall_thickness`). Sin textura, cada capa dibuja el placeholder
  procedural (fondo plano y paredes de madera).
- **Coincidencia con la colisión.** Las paredes de colisión suben
  `DangerZone.EXTENSION_ABOVE` (400 px) por encima de la boca: con textura esa
  parte queda **invisible a propósito**, es una barrera para pilas que
  sobresalen y la partida se pierde antes de que importe. Al comparar con
  `--debug-collisions`, solo cuenta la parte desde `y = 0`.
- **Artefacto.** `DropPreview.dropper_texture` se dibuja en un cuadrado de
  `dropper_size` (64 px) centrado en `aim_x`, con el borde inferior en
  `spawn_y − radius` y también durante el cooldown. Con la pieza generable más
  grande (radio 46) su borde superior queda a 10 px del borde de la pantalla;
  con una pieza más grande (F4) se recorta, y se acepta porque es depuración.

---

## 3. Sprites de los materiales

Cada `PieceData.texture` apunta a `assets/sprites/pieces/<id>.png`
(Anexo A.1 de `06`). Convención:

- **Lienzo** de 512 × 512 px, transparente y cuadrado (el catálogo rechaza una
  textura no cuadrada).
- **Cuerpo redondo** centrado de 410 px de diámetro: el 80 % del lienzo
  (`PieceVisual.TEXTURE_BODY_FILL`). El diámetro físico (`2·radius`)
  corresponde a ese 80 %, así que el sprite se dibuja en un cuadrado de lado
  `2·radius / 0,8`. El 10 % restante por lado es margen para adornos finos que
  pueden solaparse con las vecinas.
- **Qué dibuja el código y qué trae el arte.** Código: el halo de brillo
  (`glow_strength`) por detrás. Arte: todo lo demás (cuerpo, borde, luz). Con
  textura, el código **no** pinta círculo, borde, reflejo ni número; sin
  textura, dibuja el placeholder procedural completo.
- **Rotación.** `PieceVisual.rotate_texture` (`true` por defecto) hace que el
  sprite gire con la pieza. Con `false`, se mantiene derecho: sirve si el arte
  trae una luz muy marcada que no debe girar. Sin textura, el placeholder
  siempre se mantiene derecho.
- **Reducción.** La leyenda (24 px) y la vista previa reducen los sprites de
  512 px; por eso las texturas se importan con mipmaps (§4).

---

## 4. Assets y placeholders

Cada asset del Anexo A de `06_plan_iteracion_2.md` existe como **placeholder**
con su ruta, nombre, tamaño y formato definitivos. La fuente única de rutas y
tamaños es `tools/asset_spec.gd`; `tests/unit/test_asset_spec.gd` comprueba que
cada archivo la cumple.

```bash
# Crea solo los que faltan (nunca sobrescribe)
godot --headless -s tools/generate_placeholders.gd
# Además escribe las plantillas guía para el artista en docs/plantillas/
godot --headless -s tools/generate_placeholders.gd -- --templates
# Regenera todos (destructivo: pisa también los definitivos)
godot --headless -s tools/generate_placeholders.gd -- --force
```

`project.godot` activa el filtro *Linear Mipmap* y `mipmaps/generate = true`
por defecto en las texturas: los sprites de 512 px se reducen a 24 px en la
leyenda y sin mipmaps se verían con dientes.

### 4.1. Procedimiento de integración de un asset definitivo

1. Exportar el archivo con **el mismo nombre, ruta, tamaño y formato** que su
   placeholder y sobrescribirlo.
2. `godot --headless --path . --import`.
3. Ejecutar la suite: `test_asset_spec.gd` falla si el tamaño o el formato no
   coinciden.
4. Revisar en el juego (`F4` carga una pieza de nivel alto) y marcarlo como
   "definitivo" en la tabla de §4.3.

Excepciones, que requieren cambiar **una línea**:

- **Música en OGG:** sustituir la referencia de `music` en `ui/sound_set.tres`
  por `bgm_workshop.ogg`, borrar `bgm_workshop.wav` y su `.import`, y activar
  `loop` en el `.import` del OGG. `test_asset_spec.gd` acepta ambas
  extensiones.
- **Fuente:** no hay placeholder (se usa la de Godot); al añadirla se asigna en
  `ui/theme.tres`.

Los bucles de audio no se escriben en el WAV: están en el `.import`
(`edit/loop_mode=2`) de `sfx_danger_loop.wav` y `bgm_workshop.wav`, y se
conservan al sustituir el archivo.

### 4.2. Plantillas del artista (`docs/plantillas/`)

Una imagen por tamaño, sin texto. Leyenda de colores:

| Color | Significado |
| ----- | ----------- |
| Verde | Límite que debe respetarse (círculo de 410 px, interior del frasco, borde donde se apoya la pieza) |
| Rojo  | Eje o cruz de centrado; en el fondo, los bordes de la zona central del frasco |
| Gris claro (material) | Interior del cuerpo; el gris oscuro exterior es el margen para adornos |
| Rojo / azul (pergamino) | Esquinas de 32 px que no se deforman / centro que se estira |

### 4.3. Estado de assets

| Archivo | Estado |
| ------- | ------ |
| `assets/sprites/pieces/*.png` (8 materiales) | placeholder |
| `assets/sprites/scene/workshop_background.png` | placeholder |
| `assets/sprites/scene/jar_back.png` | placeholder |
| `assets/sprites/scene/jar_front.png` | placeholder |
| `assets/sprites/scene/alchemist_dropper.png` | placeholder |
| `assets/ui/parchment_panel.png` | placeholder |
| `assets/sprites/fx/sparkle.png` | placeholder |
| `assets/audio/sfx_*.wav` (7 efectos) | placeholder |
| `assets/audio/bgm_workshop.wav` | placeholder |
| Fuente del título y HUD (`assets/fonts/`) | sin fuente (usa la de Godot) |
