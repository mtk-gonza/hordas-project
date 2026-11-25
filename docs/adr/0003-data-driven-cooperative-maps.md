# ADR-0003: Mapas de datos con selección replicada por el host

- Estado: Aceptada
- Fecha: 2026-11-25

## Contexto

La arena única limita la rejugabilidad. Duplicar escenas completas para cada escenario haría difícil mantener la misma red, objetivos y reglas de combate. Además, todos los peers deben cargar el mismo escenario.

## Decisión

Definir IDs, fondo, color y modificadores en `GameMapCatalog`. El anfitrión selecciona un mapa en el lobby; el ID validado se replica al unirse y viaja en los RPC de inicio/reinicio. La sesión conserva una escena común y cambia su fondo, acento de arena y parámetros de oleada según el catálogo.

## Alternativas consideradas

- Duplicar `GameWorld` por mapa: rechazado por duplicar lógica cooperativa y aumentar riesgo de inconsistencias.
- Permitir que cada cliente elija visualmente su mapa: rechazado porque causa estados diferentes en el mismo combate.
- Transmitir una ruta de textura arbitraria: rechazado; solo se aceptan IDs del catálogo.

## Consecuencias

- Agregar un mapa requiere registrar una definición y un recurso visual sin duplicar la escena de juego.
- El catálogo es la fuente común de reglas; sus IDs y valores deben permanecer compatibles en todas las builds.
- Los tres escenarios actuales se distinguen por densidad, velocidad, salud y cadencia de miniboss; requieren playtests para balance final.
