# Estado de implementación

Actualizado: 25 de noviembre de 2026.

El proyecto es un MVP cooperativo para Godot 4.7.2, no un producto terminado. Esta revisión añade selección cooperativa de tres mapas con arenas originales y reglas de oleada propias, pasivas únicas de personaje, eventos temporizados, modificadores élite, HUD compartido y selección de campeón. También conserva armas evolucionables, golpes telegrafiados del jefe, pausa local, soporte de mando, reanimación, cofres, pilares y legado individual. La build de Windows se genera en `builds/HordasCooperativo.exe`.

## Sistemas presentes

- Host/join ENet por IP y puerto UDP; lobby de hasta cuatro peers.
- Tres mapas seleccionables por el anfitrión y replicados a toda la sesión: Distrito Neón, Jardín de Biosíntesis y Fundición Orbital. Cada uno configura fondo, acento, densidad/velocidad/resistencia enemiga y frecuencia de miniboss.
- Movimiento de teclado/mando con predicción/reconciliación, límite de tasa y enemigos autoritativos en el host.
- Seis enemigos iniciales a 1,5 s, oleada continua, minibosses cada 90 s, cofres con selección y jefe final.
- Definitiva por personaje (R/Y), pulso automático, dardos dirigidos y hojas orbitales; tres ofertas aleatorias de mejora validadas por el host y evoluciones al combinar nivel 5 con pasivas.
- Cuatro pasivas innatas conectadas a señales de enemigo eliminado y arma acertada; las reglas y recompensas se ejecutan en el host.
- Eventos globales elegidos por el host: purgar un núcleo con F/X o escoltar un dron mientras el equipo despeja su ruta. Cada misión tiene temporizador, barra y marcador de minimapa; completarla da oro de run, XP de equipo y un cofre; fallarla enfurece la horda durante 35 segundos, aumentando velocidad y daño.
- Modificadores élite por componentes hijos: escudo direccional frontal, suicida explosivo y aura que cura/refuerza enemigos cercanos. Los enemigos especiales aparecen por patrón de oleada y sus cambios lógicos se resuelven en el host.
- HUD de equipo con nivel/XP compartidos, retratos y estado de aliados, vida y minimapa de compañeros, pilares, jefe y misión activa. Se refresca a intervalos cortos en vez de reconstruirse cada frame.
- Jefe final con golpe de área: marca de peligro visible, 1.2 s para esquivar y daño decidido por el host.
- Estado abatido y reanimación cooperativa; sangrado, muerte temporal y regreso en la siguiente marca de oleada antes del jefe final. El host mantiene una asignación exclusiva de un reanimador por objetivo y un objetivo por reanimador.
- Drops de tarjetas, cofres reservados por tarjeta, tres pilares defendibles, cámara compartida y límite de distancia al escuadrón.
- Oro y mejoras permanentes locales guardados en SQLite por cuenta, con migración de perfil JSON anterior y esquema MySQL equivalente preparado para un backend autenticado. SQLite no sincroniza cuentas entre dispositivos ni protege contra edición local; el cliente nunca se conecta directamente a MySQL.
- Menú/HUD temáticos, pausa local que detiene solo al avatar propio, control de volumen general, arena pixel art, enemigos con barras de vida, animaciones y VFX.
- Créditos del paquete de sprites y documentación de arte.
- Nuevas variantes Tejedor de Almas, Mago de Tormenta, Arquero Óseo y Bruto de Peste, con paletas, estadísticas y roles diferenciados. Los magos fijan la posición del jugador, muestran un telegráfico arcano y lanzan un disparo de daño resuelto por el host.
- Los ataques de los jugadores muestran un corte curvo luminoso sincronizado al estado de ataque. El Tejedor y los Magos de Tormenta apuntan un proyectil de zona; el Bruto de Peste telegraphía y descarga un pisotón de corto alcance.
- Las criaturas conservan la animación de carrera entre pasos de IA/snapshots con una histéresis de movimiento de 0,22 s. La cadencia de carrera ahora depende del arquetipo, y los sprites usan sus hojas de seis frames correctamente.

## Verificación reciente

- Godot 4.7.2 analizó e importó el proyecto y exportó `builds/HordasCooperativo.exe` para Windows x86-64.
- Un smoke de dos procesos ENet (host y cliente reales en procesos distintos) verificó el roster, down/revive replicado, tarjeta/cofre/selección y consumo de llave, cuatro catálogos de evolución con ataque de ecos y reentrada tras la marca de oleada con media vida.
- Godot importó las nuevas texturas, registró `GameMapCatalog`, exportó la build Windows y la inició con el proceso respondiendo. Falta una partida manual que compruebe los tres mapas desde el selector y desde el lado cliente.
- La base de cuentas permanece en SQLite local; el esquema MySQL equivalente queda en `database/mysql/001_account_profiles.sql` para un backend autenticado. Aún falta implementar y desplegar ese servicio para sincronizar cuentas entre dispositivos.
- La ampliación de reanimador exclusivo, escolta móvil, furia con daño y Resource de perfil necesita smoke cooperativo específico antes de considerarse verificada en red.
- El arnés temporal de red se retiró del proyecto al concluir; los resultados quedaron en [informe de validación](verification-report.md).

## Pendientes

- Verificar G–J y los cambios recientes en una sesión cooperativa con dos o más procesos: selección de campeón, eventos y sus dos resultados, élites, HUD, cofre dorado, XP compartida y exclusividad del reanimador.
- Repetir la matriz ampliada de cuatro peers, servidor dedicado, pérdida y latencia simuladas; los resultados anteriores siguen siendo evidencia histórica.
- Probar visualmente definitiva, reanimación, cofre, pilares, misión y cámara en una partida completa.
- Ajustar frecuencia/dificultad de oleadas con playtests; las cifras actuales son valores iniciales de diseño.
- Probar redes externas, NAT/relay y hardware modesto.
- Las mecánicas G–J y las correcciones recientes necesitan playtest humano, validación visual dentro de una partida y prueba online de varios minutos.
- El JSON local detecta corrupción, pero no impide edición manual; el progreso competitivo necesita almacenamiento autoritativo de servidor.

## Pasada de coherencia (25-11-2026)

- Las criaturas ahora se eligen en función de su rol de combate. Los élites usan siluetas asociadas con el escudo direccional, la detonación o el aura; los minibosses toman variantes visuales grandes de su familia.
- La selección del anfitrión sincroniza el mismo mapa a toda la sesión, e incluye modificadores de densidad, rapidez y resistencia de la horda por escenario.
- Las bendiciones muestran el valor que aplican realmente: Corazón de Titán suma y restaura 30 de vida; Poder Rúnico suma 18% de daño.
- El bloqueo de carga de scripts que impedía instanciar enemigos se corrigió y un arranque de escena local confirmó seis criaturas iniciales. La nueva asignación visual y los eventos renombrados aún requieren una observación gráfica y multijugador.
## Actualización visual y persistencia (24-11-2026)

- Nuevas variantes de criatura: Tejedor de Almas, Mago de Tormenta, Arquero Óseo y Bruto de Peste reutilizan animaciones licenciadas del pack y añaden tintes, estadísticas y roles propios. El generador conserva a guerreros, pícaros, magos y al jefe orco.
- Los magos y sus dos variantes lanzan proyectiles arcanos de objetivo fijado: la advertencia, el disparo y el daño los calcula el host; la línea de aviso, el núcleo de carga y el impacto se replican a los clientes.
- Los ataques manuales de jugador añaden una estela curva y un destello de impacto que se muestran junto a las hojas de animación de ataque ya incluidas.
- La progresión permanente usa SQLite local mediante Godot-SQLite v4.7. El perfil se guarda por identificador local, con parámetros SQL enlazados y una migración de lectura desde el JSON antiguo.
- La capa `ProfileStore` permite sustituir SQLite por un servicio de perfiles. MySQL debe quedar detrás de un backend autenticado; el juego cliente no se conecta directamente a MySQL.
- Dependencia nativa incluida para Windows y Linux x86_64 (debug y release). Para otras plataformas hay que añadir sus bibliotecas GDExtension antes de exportar.
