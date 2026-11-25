# Informe de validación local

Actualizado: 24 de noviembre de 2026. Proyecto Godot 4.7.2; las pruebas de red usaron procesos locales independientes. Las escenas/scripts temporales se retiraron después de usarlos.

## Actualización visual y de guardado (24-11-2026)

- Godot 4.7.2 escaneó/importó la versión actual del proyecto y arrancó headless sin errores de parser o carga.
- El arranque creó `hordas_account.sqlite`; se inspeccionó su esquema y la fila de perfil con cuenta y cuatro niveles. Se migró el perfil heredado si estaba presente.
- Export Release de Windows x86-64 completada: `builds/HordasCooperativo.exe` (113,784,400 bytes) y biblioteca `libgdsqlite.windows.template_release.x86_64.dll` junto al ejecutable.
- Falta observar en una partida gráfica y cooperativa la aparición de las cuatro variantes, corte de jugador, disparo de mago y pisotón del bruto. El arranque y export no validan visualmente esos efectos ni el daño en una sesión online.

## Corrección de animación de locomoción (24-11-2026)

- Se corrigió la selección de `run`/`idle`: las posiciones del host cambian a 30 Hz y los clientes interpolan snapshots de 10 Hz; el estado de carrera ahora persiste 0,22 s sin desplazamiento observado para evitar reiniciar el ciclo entre actualizaciones.
- Se configuró velocidad de carrera por arquetipo: pícaro/arquero/mago rápido 13 fps, guerrero/tejedor 9 fps, bruto 7 fps y base 10 fps. La hoja `run.png` de estas criaturas es de 384×64 (seis frames de 64×64); idle usa frames de 32×32.
- Godot 4.7.2 volvió a importar, cargar y exportar Release Windows tras el cambio. Pendiente observación dentro de una partida gráfica para validar la percepción de fluidez en pantalla.
- Tamaño de la build corregida: 113,784,400 bytes. La ejecuté y dejé la ventana del juego abierta en el menú.

## Build actual tras la ampliación

- Reimportación, análisis y exportación Release con Godot 4.7.2: código de salida 0.
- Arranque headless del proyecto principal durante 180 frames y escaneo/importación headless del editor: código de salida 0, sin errores de script.
- La última exportación incluye reanimador exclusivo, escolta móvil, furia con aumento de velocidad/daño y `AccountProfile` como Resource serializado en JSON.
- Tamaño de la última exportación Windows x86-64: 113,772,120 bytes.
- No se repitió smoke ENet después de estos cambios; la prueba de arranque comprueba carga/parsing, no los resultados de misión, la reserva de reanimación o la sincronización entre pares.
- Un smoke nuevo de dos procesos ENet pasó: roster de dos, estado abatido y reanimación observados por el cliente, tarjeta que habilita cofre, oferta/elección de mejora y consumo de llave, cuatro definiciones de evoluciones temáticas con disparo de eco, y retorno tras bleedout en la siguiente marca de minuto con 50% de vida.
- El smoke encontró y permitió corregir dos defectos reales durante esta pasada: referencia de cofre ya liberada y limpieza incompleta del diccionario al reclamar el cofre. También se corrigió la HUD que no parseaba en runtime y se validó al arrancar ambas instancias.
- El arnés temporal se retiró. No se repitió en esta pasada la matriz de cuatro peers, servidor dedicado ni la medición de rendimiento; esos resultados históricos se mantienen separados abajo.
- Las nuevas opciones aleatorias de nivel, armas secundarias, pausa local, soporte de mando y golpe telegrafiado del jefe compilan e importan, y el proyecto arranca headless. Todavía no se simularon con clientes reales ni se validó visualmente la ventana de esquiva.
- En la revisión anterior, `game_world.tscn` generó seis criaturas después de 180 ticks; ese smoke no se repitió para esta exportación.

## Matriz de resultados históricos

| Área | Resultado observado |
| --- | --- |
| Importación | Godot headless, código 0, sin errores de parser/importación. |
| Sesión de dos peers | Host y cliente ENet cargaron el mundo; ambos observaron roster de dos. |
| Cuatro jugadores | Tres clientes se unieron al host; host y clientes observaron roster de cuatro. |
| Desconexión en lobby | Con tres clientes conectados, uno se retiró antes del inicio; el host vio bajar el lobby de tres peers a dos y arrancó con roster de tres. |
| Desconexión en partida | Con roster de cuatro, un cliente se retiró; el host eliminó ese jugador y quedó con roster de tres. |
| Victoria | El host mató al jefe por la ruta de daño; host y cliente recibieron `victory` y mostraron el banner de victoria. |
| Derrota | El host llevó a cero la vida de todo el equipo; host y cliente recibieron `defeat` y mostraron el banner de derrota. |
| Red degradada | Proxy UDP local con 60 ± 20 ms por dirección y 0.5% de pérdida. El cliente movió al jugador durante 2 s; el host confirmó ~490 px y ACK 185. Una sesión de victoria también terminó sin errores del motor. |
| Servidor dedicado | Servidor headless y cliente: inicio automático tras 15 s, escena lista y roster de dos. El ejecutable exportado también aceptó un cliente. En otra prueba acelerada se generó el jefe, se derrotó y ambos peers vieron victoria. |
| Horda de 250 | Host headless y un cliente recibieron 250 enemigos. Muestra de 2.5 s con IA activa; se colocaron fuera del alcance del arma para conservar población durante la medición. |
| Exportación Windows | Release x86-64, 109,940,144 bytes; el ejecutable inició headless con código 0 y su modo dedicado aceptó un cliente. |

## Medición de rendimiento

La máquina de prueba tenía un AMD Ryzen 7 9800X3D (8 núcleos/16 hilos). En el proceso host headless con un cliente local y 250 enemigos activos durante 2.5 s, Godot reportó:

- 145 FPS headless observados.
- Tiempo de proceso medio 7.026 ms, máximo 16.884 ms.
- Tiempo de física medio 2.557 ms, máximo 3.683 ms.
- Memoria estática reportada: 34.34 MiB.

La muestra mide una escena concreta en un PC de gama alta; no representa rendimiento gráfico ni mínimos de hardware. Tampoco combina cuatro clientes con 250 enemigos.

## Trabajo restante antes de publicar

- Playtests humanos de una run completa de cinco minutos y calibración de dificultad/progresión.
- Pruebas desde redes externas y NAT; el MVP requiere conexión directa al UDP del host o un servidor dedicado accesible.
- Perfil en equipos modestos y con cuatro clientes/250 enemigos al mismo tiempo.
- Exportación de otras plataformas si se desean, firma y distribución del ejecutable.
