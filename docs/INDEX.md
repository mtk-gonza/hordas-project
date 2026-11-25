# Índice de documentación

## Orientación del proyecto

- [Contexto actual](CONTEXT.md): qué es el juego, cómo se compone, cómo ejecutarlo y qué falta validar.
- [Estado de implementación](implementation-status.md): sistemas presentes, evidencia y pendientes.
- [Informe de verificación](verification-report.md): verificaciones técnicas ejecutadas previamente.

## Arquitectura y diseño

- [Arquitectura técnica](architecture/architecture.md): límites de módulos y diseño general de red/juego.
- [Mecánicas cooperativas](architecture/swarm_mechanics.md): habilidades, hordas, eventos, progresión y controles.
- [Mapas seleccionables](architecture/maps.md): IDs, presentación, modificadores y sincronización del anfitrión.
- [Persistencia de perfiles](architecture/persistence.md): SQLite local y ruta de evolución a MySQL autenticado.
- [Decisiones de arquitectura (ADR)](adr/): decisiones aceptadas con alternativas y consecuencias.

## Arte y recursos

- [Créditos, fuentes y licencias](../art/ASSET_CREDITS.md).
- [Lista de recursos de arte](ART_ASSET_SHORTLIST.md).

## Implementación

- [Código por características](../features/): sesión, jugadores, enemigos, armas, mapas, objetivos y UI.
- [Servicios globales](../autoload/): red, perfiles y progresión meta.
- [Esquema MySQL](../database/mysql/001_account_profiles.sql): DDL para el servicio backend futuro.
