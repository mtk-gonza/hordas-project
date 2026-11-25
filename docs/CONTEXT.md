# Contexto del proyecto

Actualizado: 25 de noviembre de 2026.

## Resumen

Hordas Cooperativo es un roguelite de supervivencia cooperativo para 1–4 jugadores en Godot 4.7.2. La partida dura cinco minutos y termina con un jefe; el grupo obtiene mejoras aleatorias, armas evolucionables y objetivos temporizados. La dirección actual combina fondos 2.5D de ciencia ficción con personajes y criaturas en sprites pixel art. Es un MVP en iteración, no un lanzamiento terminado.

## Estado jugable

- ENet conecta un host autoritativo y hasta tres clientes; el mismo código puede correr headless como servidor dedicado.
- El host procesa oleadas, IA, daño y progresión. El jugador local predice movimiento, mientras el resto de jugadores y enemigos se presentan con estado sincronizado/interpolado.
- El lobby ofrece tres mapas: Distrito Neón, Jardín de Biosíntesis y Fundición Orbital. El anfitrión selecciona y replica el mapa; cada escenario modifica densidad, resistencia, velocidad y frecuencia de miniboss.
- Hay habilidades E/R, armas automáticas/secundarias, evolución, pasivas, élites, jefes, down/revive, eventos, cofres, pilares y HUD de escuadrón.
- Los perfiles locales persisten oro y mejoras en SQLite. Existe el DDL MySQL, pero no hay todavía servicio de autenticación/HTTP ni sincronización de cuentas entre equipos.

## Puntos de entrada

- Proyecto y escena principal: `project.godot` → `scenes/boot/boot.tscn`.
- Menú y lobby: `features/ui/main_menu.gd`.
- Coordinación de red: `autoload/network_manager.gd`.
- Raíz de partida/cámara/arena: `features/session/game_world.gd`.
- Catálogo de mapas: `features/maps/map_catalog.gd`.
- Oleadas y simulación de hordas: `features/enemy/enemy_spawner.gd` y `features/enemy/base_enemy.gd`.
- Persistencia: `autoload/meta_progression.gd`, contrato `autoload/profile_store.gd` y SQLite `autoload/sqlite_profile_store.gd`.

## Ejecutar localmente

Usar Godot 4.7.2 y abrir `project.godot`. Para una partida local, crear una sala y pulsar Iniciar; para una segunda instancia, conectar a `127.0.0.1:2456`. El README contiene los controles y la línea de exportación Windows. La build no se versiona para evitar commits de ejecutables grandes.

## Límites conocidos

- La red directa ENet no resuelve NAT, relay ni matchmaking.
- SQLite vive en el perfil de cada dispositivo; los datos no son autoritativos frente a manipulación local.
- MySQL requiere un servicio autenticado; no incluir credenciales ni conectar la aplicación cliente directamente a la base.
- El contenido y los mapas todavía requieren playtests de balance y validación cooperativa/visual por mapa.
- La dirección visual mezcla fondos ilustrados y sprites pixel art; el trabajo de coherencia visual continúa.

## Fuente de verdad

El código ejecutable define el comportamiento actual. `docs/implementation-status.md` lleva el estado de implementación; [`INDEX.md`](INDEX.md) enlaza documentos y ADRs. Si un documento antiguo de arquitectura contradice al código o a un ADR aceptado, actualizarlo antes de usarlo como especificación.
