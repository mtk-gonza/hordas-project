# Mapas seleccionables

`GameMapCatalog` es la única fuente de mapas, fondos, color de borde y ajustes de oleadas. El menú permite al anfitrión seleccionar el escenario; el identificador validado viaja en el RPC de inicio/reinicio y cada cliente carga el mismo fondo antes de que aparezca el escuadrón. La lógica de red y el layout de objetivos son compartidos.

| ID | Escenario | Ajuste de la incursión |
| --- | --- | --- |
| `neon_district` | Distrito Neón | Ritmo estándar. |
| `biosynth_garden` | Jardín de Biosíntesis | Oleadas más espaciadas, criaturas más resistentes y lentas; minibosses cada 105 s. |
| `orbital_foundry` | Fundición Orbital | Oleadas 18% más densas, criaturas más rápidas pero frágiles; minibosses cada 75 s. |

Los fondos se guardan bajo `art/processed/`. Sus autores son originales generados para este proyecto. El mapa se limita a un identificador corto; nunca se transmiten rutas de archivos elegidas por clientes. Para sumar escenarios, añadir sus datos a `features/maps/map_catalog.gd` y la textura a la ruta declarada allí.
