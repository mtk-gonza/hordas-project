# Persistencia de perfiles

## Estado actual

La progresión local usa SQLite con el GDExtension [godot-sqlite](https://github.com/2shady4u/godot-sqlite), versión v4.7. El archivo se crea en `user://hordas_account.sqlite`. `MetaProgression` conserva la API usada por el menú y la partida, mientras `ProfileStore` define la frontera de almacenamiento y `SqliteProfileStore` implementa la base local.

El perfil incluye oro y niveles de cuatro mejoras permanentes. El identificador aleatorio local está en `user://account_id.txt`; las consultas de escritura y lectura enlazan los valores para evitar inyección SQL. Las restricciones de tabla validan rango de oro y niveles. Al abrir una instalación antigua, el sistema importa `account_profile.json` o su respaldo si aún no existe una fila SQLite.

SQLite es una base local por dispositivo. No sincroniza las cuentas entre equipos y no impide que una persona modifique sus archivos locales.

## Camino a MySQL

No conectar el ejecutable cliente directamente a MySQL: incluir credenciales en el juego permite extraerlas y falsificar operaciones. El siguiente paso para perfiles compartidos es reemplazar `ProfileStore` con un adaptador HTTP hacia un servicio dedicado. Ese servicio valida identidad, progreso y recompensas, y usa MySQL detrás de la API.

Se incluye el esquema MySQL equivalente en `database/mysql/001_account_profiles.sql`. Conserva los campos de perfil (`account_id`, `gold`, niveles de mejoras y `updated_at`) usados por `AccountProfile`, pero las consultas y transacciones MySQL quedan en el servicio de servidor; el cliente continúa usando SQLite local o una futura implementación HTTP del contrato `ProfileStore`.

Contrato recomendado de API:

- `GET /v1/profile`: carga oro y mejoras del usuario autenticado.
- `POST /v1/profile/purchase`: acepta un identificador de mejora; el servidor calcula el precio y aplica el débito en una transacción.
- `POST /v1/runs/reward`: el servidor valida el resultado de la partida y acredita una recompensa idempotente.
- Toda conexión usa TLS; tokens de sesión cortos; tablas MySQL con claves foráneas, restricciones y migraciones versionadas.

Para modo dedicado autoritativo, el servidor mantiene el perfil de cada cuenta. Para P2P, SQLite sólo da persistencia personal sin autoridad confiable; los datos no deben tratarse como economía competitiva.

## Dependencia de plataforma

El proyecto incluye bibliotecas de Godot-SQLite v4.7 para Windows x86_64 debug y release. Hay que incluir el artefacto correspondiente de cada plataforma objetivo en `addons/godot-sqlite/bin/` y mantener sincronizado `gdsqlite.gdextension`. La extensión upstream declara compatibilidad mínima con Godot 4.5; el proyecto está fijado a Godot 4.7.2.
