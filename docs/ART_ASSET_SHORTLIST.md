# Recursos visuales recomendados

Selección para el juego top-down de supervivencia. Se priorizan recursos gratuitos, sprites legibles a escala pequeña y ataques con hojas de animación reutilizables.

## Criaturas y animación

**[Monsters & Creatures — Free 16×16 Top-Down RPG Enemy & Boss Pack](https://michelclauwaertgmailcom.itch.io/monsters-creatures-free-16x16-top-down-rpg-enemy-boss-pack)**

- La página ofrece el pack gratis y enumera 40 monstruos, 6 jefes de fase 2 y más de 3.400 frames, incluyendo ataques, daño recibido, muerte, proyectiles, efectos y botín.
- El tamaño 16×16 y la paleta coinciden con el estilo pixel-art del proyecto. Es la primera opción para poblar la horda con siluetas y patrones distintos.
- La página permite uso comercial y modificación; pide no revender ni redistribuir los archivos originales como pack. Revisar los términos incluidos antes de publicar el juego.

## Efectos y animaciones de ataque

**[Spells & Skills — Free 16×16 Magic Combat Effects VFX](https://michelclauwaertgmailcom.itch.io/spells-skills-free-16x16-magic-combat-effects-vfx)**

- Pack gratuito de más de 1.500 frames: proyectiles, impactos, áreas, estelas de corte, estados y más de 100 iconos.
- Encaja con la escala del pack de criaturas anterior y sirve para animar el pulso, las hojas orbitantes, los dardos y las definitivas.
- Importar cada efecto como `SpriteFrames` independiente y reproducirlo en clientes mediante eventos visuales RPC; el Host sigue siendo quien calcula el daño.

## Iconos de equipamiento

**[Larchrow RPG Item Icons — 239 Pixel Items](https://larchrow.itch.io/larchrow-rpg-item-icons)**

- 239 iconos 16×16 de objetos y equipamiento, apropiados para cofres, inventario y las ranuras del HUD.
- La página indica uso comercial y no comercial; el crédito es opcional. Verificar el archivo de licencia del ZIP antes de distribuir.

## Alternativa de criaturas animadas

**[Top-Down Monsters LITE](https://tinytileset.itch.io/top-down-monsters-free)** ofrece dos monstruos animados en cuatro direcciones y dos ataques por criatura. Es útil para prototipar animaciones antes de integrar un catálogo grande, aunque su escala 32×32 puede desentonar con el pack 16×16.

## Integración propuesta

Los tres packs gratuitos se descargaron y se importó una selección al proyecto. Las tiras fuente completas se conservaron fuera del árbol exportable en `D:\projects\hordas-project-art-source`; los archivos seleccionados y copias de sus licencias están en `res://art/external/`. Los sprites importados tienen filtro nearest y se usan como `AnimatedSprite2D` en el juego.

La selección activa incluye veinte criaturas 16×16 con animaciones de cuatro direcciones (`idle`, `walk`, `attack`, `hurt`, `death` y `special`) y los seis jefes con dos ataques, animación de daño/muerte, intro y sprites de segunda fase. El juego elige el jefe de la expedición desde ese catálogo y cambia sus sprites al cruzar el 50% de vida. También hay iconos reales para las cinco ranuras de equipo y cuatro definitivas temáticas. Los ataques de pulso y definitivas usan tiras de efectos animadas; los cofres muestran una animación de apertura al reclamar una mejora. Se conserva el pack de criaturas anterior como respaldo.

No se copiaron los packs enteros al proyecto: solo los sprites utilizados, para reducir el tamaño del juego exportado y no distribuir los archivos fuente como packs independientes.
