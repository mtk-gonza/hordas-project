# Mecánicas de supervivencia cooperativa

Este documento describe la implementación jugable de las seis mecánicas agregadas al proyecto. El host valida daño, estados de jugador, elección de recompensas y objetivos; los clientes envían solicitudes y presentan el resultado replicado.

## A. Definitivas por personaje

`UltimateDefinition` guarda nombre, radio, daño, enfriamiento, duración y color en Resources bajo `features/player/ultimates/`. `UltimateCatalog.for_character()` asigna una definición al personaje elegido en el menú y enviada por el dueño al informar que el mundo está listo. El jugador usa **R** o **Y** en mando. El host valida dueño, estado y cooldown, aplica el daño en área y replica la animación de estallido. `replicated_ultimate_cooldown_left` se replica para la barra del HUD.

La habilidad activa **E** tiene 10 segundos de enfriamiento, inflige daño en un radio de 245 unidades y empuja a la horda. El host valida la petición RPC, procesa daño y knockback; clientes reciben únicamente el cooldown replicado y el efecto visual. **F** o **X** interactúa con los eventos del mapa. La barra de habilidades diferencia E, R, arma automática y armas adquiridas.

El punto de entrada de red vive en `features/player/player.gd`:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func _request_ultimate() -> void:
	if not multiplayer.is_server() or replicated_downed or replicated_dead:
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_activate_ultimate()
```

La llamada local del host va directamente a `_activate_ultimate()`. El daño se aplica contra la lista de enemigos autoritativa; los clientes no calculan daño.

## B. Evolución de armas

El pulso automático tiene `replicated_weapon_level` de 1 a 5 y `replicated_attack_speed_passive`. Las mejoras de nivel refuerzan daño y alcance. Con nivel 5 y la pasiva, `_check_weapon_evolution()` activa `replicated_weapon_evolved`, que multiplica el daño, aumenta el alcance y mejora el cooldown. `WeaponEvolutionCatalog` da a cada campeón una variante mecánica: el Guardián repele, la Invocadora genera tres ecos rápidos, la Custodia Lunar amplía el área y cura al acertar, y la Guardiana del Bosque crea ecos lentos de gran empuje. Sus nombres y colores se replican en HUD/VFX.

```gdscript
if replicated_weapon_level >= 5 and replicated_attack_speed_passive and not replicated_weapon_evolved:
	replicated_weapon_evolved = true
	replicated_weapon_damage *= 1.55
	replicated_attack_range += 72.0
	replicated_attack_cooldown = maxf(0.3, replicated_attack_cooldown * 0.72)
```

Los campos de nivel, pasiva y evolución se envían con el `MultiplayerSynchronizer` del jugador.

Las subidas de nivel ofrecen tres mejoras distintas elegidas por el servidor a partir de un conjunto filtrado por topes: pulso, cadencia, salud, dardos dirigidos, hojas orbitales, daño y velocidad. El cliente envía el ID visible; el host comprueba que siga dentro de `replicated_upgrade_choices` y que haya un token. Los dardos priorizan hasta tres objetivos y las hojas dañan enemigos en un radio orbital; ambos trazos visuales se replican desde el host. Dardos nivel 5 + cadencia los evolucionan a una descarga adicional; hojas nivel 5 + 36% de daño personal las evolucionan con más radio y daño.

## C. Abatido y reanimación

Al llegar a cero de salud, el servidor activa `replicated_downed`, inicia 25 segundos de sangrado y conserva al jugador en la escena. Cada tick, el servidor asigna un único aliado vivo dentro de 62 unidades mediante un lease de 450 ms; ese aliado no puede reanimar simultáneamente a otro compañero. Cinco segundos de ayuda completan la reanimación y restauran 35% de salud máxima. Si el sangrado termina primero, el jugador espera a la siguiente marca de oleada de minuto entero y regresa con 50% de vida y 2,5 segundos de invulnerabilidad. Durante el tramo del jefe, cuando ya no hay otra marca antes del final, no se programa regreso.

La búsqueda de reanimadores se ejecuta solo en `Player._tick_downed()`. El círculo y el progreso se dibujan localmente en `PlayerVisual`; el servidor calcula, reserva y replica el peer aliado reanimador (`replicated_reviver_peer_id`), y el HUD lo identifica. La identidad de quien ayuda no se acepta desde un RPC del cliente.

## D. Cofres y pilares de combate

Cada 90 segundos antes del jefe aparece un mini-jefe. Al morir, deja una tarjeta de acceso replicada; cualquier aliado vivo la recoge al acercarse y el servidor genera un cofre a corta distancia. La tarjeta se consume al abrir el cofre y el primer aliado cercano recibe tres alternativas distintas de cinco recompensas. El host reserva la tarjeta, ofrece 30 segundos para elegir, revalida estado y distancia, y devuelve la tarjeta si la oferta expira o el jugador sale del radio. Rechaza cualquier selección de otro peer o una opción que no se ofreció. Las recompensas mejoran nivel de arma, pasiva, vida, daño o cooldown de definitiva.

Tres pilares se colocan en el mapa para todos los peers. El servidor aumenta su progreso cuando un jugador vivo permanece cerca y no hay enemigos disputando el área. Tras ocho segundos, el pilar entrega al equipo daño temporal, velocidad temporal o curación, y entra en cooldown. Su progreso y activación se replican como estado visual.

## E. Legado persistente

`autoload/account_profile.gd` define el Resource de cuenta; `autoload/meta_progression.gd` lo carga y persiste con `SqliteProfileStore` en `user://hordas_account.sqlite`. La tabla conserva oro y cuatro niveles con restricciones SQL y parámetros enlazados. `account_profile.json` de instalaciones antiguas se importa al crear el perfil SQLite. `ProfileStore` es el contrato para otro almacenamiento. SQLite mantiene el perfil en el dispositivo y se puede editar localmente; para perfiles compartidos o economía competitiva, un backend autenticado debe validar compras y recompensas, y guardar los datos en MySQL. El ejecutable no incluye credenciales de base de datos.

## F. Cámara compartida y círculo de batalla

`SharedBattleCamera` promedia la posición de los jugadores que no están muertos y aleja el zoom según la distancia entre compañeros. El servidor también limita el movimiento deseado al círculo de 520 unidades alrededor del centro del resto del equipo. El control se aplica después del movimiento autoritativo y antes de replicar la posición.

## G. Pasivas innatas

`CharacterPassiveBase` conecta cada instancia de jugador a `on_enemy_killed` y `on_weapon_fired`. Los cuatro recursos de pasiva modifican el combate en el host: el Guardián gana impulso de movimiento al eliminar; la Invocadora emite un eco tras cinco ataques con impactos; la Custodia Lunar cura a la persona viva con menor proporción de vida después de cuatro impactos; la Guardiana del Bosque se cura con sus eliminaciones. Las señales solo se emiten desde daño autoritativo, y el eco no vuelve a contarse como ataque original.

## H. Eventos de mapa con límite de tiempo

`ObjectiveManager` programa el primer evento al segundo 75 y vuelve a intentar otro cada 105 segundos hasta el jefe. El host escoge entre purgar un núcleo corrupto (120 puntos de corrupción; pulsar **F/X** cerca para activarlo) y escoltar el dron de extracción, que recorre tres puntos mientras jugadores vivos permanecen cerca y despejan la zona. La escolta debe llegar en 75 segundos. El RPC del núcleo valida peer, vida, abatimiento, distancia y frecuencia. Un éxito da 220 de oro al cierre de la partida, 120 XP al equipo y un cofre de elección gratuito. Un fallo aplica 35 segundos de furia a los enemigos actuales y nuevos (32% más velocidad y daño). El estado, temporizador, progreso, vida y posición se replica; el HUD muestra barras de tiempo/objetivo y el minimapa indica el destino.

## I. Modificadores élite

`BaseEnemy` agrega un componente hijo según el tipo recibido en el payload del `MultiplayerSpawner`. El escudo reduce 78% del daño entrante desde el arco frontal; el suicida detona en contacto, daña aliados en radio y se consume; el aura restaura vida y otorga protección breve a enemigos pequeños cercanos. Un patrón determinista de IDs selecciona aproximadamente tres élites cada trece spawns regulares. Fallar una misión activa una mejora temporal de velocidad para las hordas; el host simula todos estos efectos y los clientes muestran anillos/telegraph.

## Variantes visuales y ataques de criaturas

El spawner distribuye Tejedores de Almas, Magos de Tormenta, Arqueros Óseos y Brutos de Peste además de los esqueletos base, guerreros, pícaros, magos y el guardián final. Cada arquetipo selecciona criaturas de su familia visual (por ejemplo, voladores veloces para pícaros, entidades arcanas para magos y criaturas pesadas para brutos); los élites muestran siluetas acordes a su modificador: escudo, explosión o aura. Las variantes reutilizan hojas animadas licenciadas y estadísticas de rol, sin duplicar texturas.

Los tres arquetipos mágicos fijan la posición actual del objetivo, la marcan durante 0,82 s y resuelven 11 de daño en un radio de 42 unidades si el jugador no esquiva. El Bruto marca un anillo de 118 unidades durante 0,92 s y descarga un pisotón por 1,15 veces su daño de contacto. La simulación y daño se resuelven en el host; líneas, carga y anillos se replican por RPC. Los jugadores muestran un arco de corte de 0,24 s junto a la animación de ataque del spritesheet.

## J. HUD compartido

`TeamHUD` es un `Control` de dibujo ligero dentro del `CanvasLayer` del HUD. Con una actualización de 120 ms muestra XP y nivel de equipo, hasta cuatro retratos con salud/estado, puntos de pilares, aliados, jefe y la misión. No crea widgets por entidad ni hace layout cada frame. El dueño conserva sus barras individuales de salud, XP y cooldown.

## Golpe del jefe final

El guardián puede marcar la posición de un objetivo cercano cada 7,4 segundos. El área de 210 unidades se telegrafía durante 1,2 segundos; al terminar, el servidor aplica 1,65 veces el daño de contacto a los jugadores que siguen dentro. Salir del círculo evita el golpe. El cliente dibuja el aviso y el anillo de impacto recibidos por RPC.

## Pausa local y mando

Esc o Start abre una pausa local. El juego no congela el árbol de escena compartido: el jugador pausado notifica al host, deja de moverse y sus armas/definitiva no se ejecutan; la horda sigue atacando a todo el escuadrón. El host valida que el RPC venga del dueño del personaje. WASD/flechas y el stick izquierdo mueven; espacio/A ataca manualmente; E/B lanza la habilidad de área; R/Y activa la definitiva.

## Configuración y controles

- **WASD / flechas:** movimiento.
- **Espacio / A:** pulso automático/manual.
- **E / B:** habilidad de área de corto enfriamiento.
- **R / Y:** definitiva del personaje.
- **F / X:** interactuar con el evento de mapa activo.
- **Esc / Start:** pausa local; la run continúa para el resto del escuadrón.
- Los scripts de escena: `features/objectives/objective_manager.gd` y `scenes/session/game_world.tscn`.
- La lista de definitivas: `features/player/ultimate_catalog.gd` y `features/player/ultimates/`.
