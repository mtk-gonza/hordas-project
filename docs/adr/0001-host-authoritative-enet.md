# ADR-0001: Host autoritativo sobre ENet

- Estado: Aceptada
- Fecha: 2026-11-25

## Contexto

La partida cooperativa admite hasta cuatro jugadores y una horda de muchas entidades. Compartir la simulación entre todos los peers permitiría resultados divergentes en daño, oleadas y progresión. ENet directo cubre partidas hospedadas y también permite ejecutar el mismo host headless.

## Decisión

Usar topología cliente-servidor sobre ENet/UDP. En partidas P2P, el peer host es autoridad; para despliegue sin jugador anfitrión, ejecutar la misma autoridad en servidor dedicado. El host calcula IA, impactos, salud, oleadas, recompensas y estado persistente. El cliente dueño predice solo su movimiento y solicita acciones, que el host valida. Los clientes interpolan los snapshots de enemigos.

## Alternativas consideradas

- Malla P2P: rechazada porque complica NAT/conexión y exige resolver conflictos de estado.
- Simulación de enemigos en cada cliente: rechazada por divergencia y mayor superficie de trampas.
- Servidor dedicado como único modo: pospuesto; requiere infraestructura que el MVP no tiene.

## Consecuencias

- Mantiene una sola verdad de combate y una ruta directa a servidor dedicado.
- El host jugador tiene ventaja de latencia y no es una autoridad confiable para economía competitiva.
- ENet directo necesita UDP accesible; relay, matchmaking y traversal de NAT quedan fuera del alcance actual.
- Los RPC de daño y recompensas deben seguir siendo validados por el host.
