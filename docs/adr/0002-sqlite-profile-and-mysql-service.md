# ADR-0002: SQLite local y MySQL detrás de un servicio autenticado

- Estado: Aceptada
- Fecha: 2026-11-25

## Contexto

Las cuentas necesitan persistir oro y mejoras meta desde la primera versión. SQLite funciona sin servidor ni credenciales y ya implementa el contrato local `ProfileStore`. Las cuentas compartidas entre dispositivos requerirán autoridad y autenticación.

## Decisión

Usar SQLite local como almacenamiento inicial, implementado por `SqliteProfileStore`. Mantener el contrato `ProfileStore` independiente del proveedor. Para persistencia remota, el cliente se comunicará con un servicio autenticado (por ejemplo, HTTP/TLS) y ese servicio usará MySQL. No conectar ni incluir credenciales de MySQL en el ejecutable. El esquema compatible se mantiene en `database/mysql/001_account_profiles.sql`.

## Alternativas consideradas

- Conexión directa del cliente a MySQL: rechazada porque expondría credenciales y permitiría falsificar compras/recompensas.
- Solo JSON local: rechazado como almacenamiento principal porque no ofrece consultas/transacciones adecuadas; se conserva únicamente la migración desde partidas antiguas.
- MySQL para instalaciones individuales: pospuesto por requerir infraestructura y configuración externa.

## Consecuencias

- El progreso de una instalación puede guardarse inmediatamente en `user://hordas_account.sqlite`.
- El progreso local es modificable y no se sincroniza entre dispositivos.
- La migración local JSON→SQLite y el DDL MySQL comparten los campos de oro y mejoras.
- La API remota, autenticación, transacciones de recompensas e identidad de cuenta todavía deben implementarse antes de sincronizar cuentas.
