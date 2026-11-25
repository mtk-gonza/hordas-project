# Hordas Cooperativo

Roguelite cooperativo de supervivencia hecho en Godot 4.7.2 con GDScript 2.0. La referencia de ritmo es un modo de horda de cinco minutos: el equipo sobrevive oleadas, mejora armas durante la partida y enfrenta una criatura alfa. El juego usa criaturas y personajes propios; el arte combina sprites pixel art con fondos ilustrados 2.5D y sigue en desarrollo.

## Ejecutar

1. Abrir la carpeta del proyecto con Godot 4.7.2 y ejecutar el proyecto (F6/F5). La escena de inicio abre el menú.
2. El anfitrión elige personaje y mapa, crea la sala UDP y pulsa **Iniciar expedición** cuando los aliados se hayan unido.
3. Los demás eligen personaje y se conectan mediante la IP y el puerto del anfitrión. La selección de mapa del anfitrión se replica al lobby y a la partida.

Por defecto se usa el puerto UDP `2456`. Para jugar por Internet, el host debe permitir o reenviar ese puerto. ENet directo no incluye matchmaking, relay ni traversal de NAT.

### Controles

- **WASD / flechas / stick izquierdo:** mover.
- **Espacio / A:** ataque manual; el pulso también busca enemigos automáticamente.
- **E / B:** habilidad de área de corto enfriamiento.
- **R / Y:** definitiva del personaje.
- **F / X:** interactuar con el evento de mapa activo.
- **Esc / Start:** pausa local; el resto del equipo continúa.

## Mapas

- **Distrito Neón:** ritmo estándar.
- **Jardín de Biosíntesis:** criaturas más resistentes y lentas; oleadas más espaciadas.
- **Fundición Orbital:** criaturas más rápidas y frágiles, oleadas más densas y minibosses más frecuentes.

El anfitrión selecciona el mapa en el menú. Catálogo y reglas en [`features/maps/map_catalog.gd`](features/maps/map_catalog.gd); arquitectura en [`docs/architecture/maps.md`](docs/architecture/maps.md).

## Persistencia de cuentas

La progresión local persiste oro y mejoras permanentes en SQLite mediante `ProfileStore`. El esquema MySQL para un futuro backend autenticado está en [`database/mysql/001_account_profiles.sql`](database/mysql/001_account_profiles.sql). El cliente no se conecta directamente a MySQL; la sincronización entre dispositivos requiere implementar el servicio seguro descrito en [`docs/architecture/persistence.md`](docs/architecture/persistence.md).

## Arquitectura

- `autoload/`: red, progreso meta y acceso a perfiles.
- `features/`: sesión, jugadores, enemigos, mapas, armas, objetivos y UI.
- `scenes/`: escenas de inicio, menú, partida y servidor dedicado.
- `art/external/`: sprites y licencias de origen; `art/processed/`: fondos y recursos integrados.
- `database/`: esquemas SQL para persistencia local/remota.

El host/servidor autoritativo procesa daño, oleadas, progresión y enemigos. Los jugadores predicen su propio movimiento; los clientes interpolan las posiciones de la horda.

## Documentación

- Índice: [`docs/INDEX.md`](docs/INDEX.md)
- Contexto actual del proyecto: [`docs/CONTEXT.md`](docs/CONTEXT.md)
- Estado y pendientes: [`docs/implementation-status.md`](docs/implementation-status.md)
- Arquitectura técnica: [`docs/architecture/architecture.md`](docs/architecture/architecture.md)
- Mecánicas cooperativas: [`docs/architecture/swarm_mechanics.md`](docs/architecture/swarm_mechanics.md)
- Mapas: [`docs/architecture/maps.md`](docs/architecture/maps.md)
- Decisiones (ADR): [`docs/adr/`](docs/adr/)
- Créditos y licencias de arte: [`art/ASSET_CREDITS.md`](art/ASSET_CREDITS.md)

## Exportar para Windows

Con las plantillas de exportación de Godot instaladas:

```powershell
New-Item -ItemType Directory -Force builds
godot --headless --path . --export-release "Windows Desktop" "builds/HordasCooperativo.exe"
```

Los ejecutables y archivos temporales de validación se mantienen fuera del repositorio; cada persona puede regenerar su build local.
