extends "res://autoload/profile_store.gd"
class_name SqliteProfileStore

const DATABASE_PATH: String = "user://hordas_account.sqlite"
const TABLE_NAME: String = "account_profiles"

var _database: Object
var _ready: bool = false

func open() -> bool:
	if _ready:
		return true
	if not ClassDB.class_exists("SQLite"):
		push_error("SQLite GDExtension no está disponible. Comprueba addons/godot-sqlite.")
		return false
	_database = ClassDB.instantiate("SQLite")
	if _database == null:
		push_error("No se pudo crear la conexión SQLite.")
		return false
	_database.set("path", DATABASE_PATH)
	_database.set("verbosity_level", 0)
	_database.set("foreign_keys", true)
	if not bool(_database.call("open_db")):
		push_error("No se pudo abrir la base SQLite: %s" % String(_database.get("error_message")))
		_database = null
		return false
	if not _execute("""
		CREATE TABLE IF NOT EXISTS account_profiles (
			account_id TEXT PRIMARY KEY NOT NULL,
			gold INTEGER NOT NULL DEFAULT 0 CHECK(gold >= 0),
			damage INTEGER NOT NULL DEFAULT 0 CHECK(damage BETWEEN 0 AND 10),
			health INTEGER NOT NULL DEFAULT 0 CHECK(health BETWEEN 0 AND 10),
			speed INTEGER NOT NULL DEFAULT 0 CHECK(speed BETWEEN 0 AND 10),
			duration INTEGER NOT NULL DEFAULT 0 CHECK(duration BETWEEN 0 AND 10),
			updated_at INTEGER NOT NULL DEFAULT (unixepoch())
		);
	"""):
		close()
		return false
	_ready = true
	return true

func load_profile(account_id: String) -> Dictionary:
	if not _ready or account_id.is_empty():
		return {}
	if not _execute("SELECT gold, damage, health, speed, duration FROM %s WHERE account_id = ?;" % TABLE_NAME, [account_id]):
		return {}
	var rows: Array = _database.get("query_result") as Array
	if rows.is_empty() or not rows[0] is Dictionary:
		return {}
	var row: Dictionary = rows[0] as Dictionary
	return {
		"version": 1,
		"gold": int(row.get("gold", 0)),
		"upgrades": {
			"damage": int(row.get("damage", 0)),
			"health": int(row.get("health", 0)),
			"speed": int(row.get("speed", 0)),
			"duration": int(row.get("duration", 0))
		}
	}

func save_profile(account_id: String, profile: AccountProfile) -> bool:
	if not _ready or account_id.is_empty() or not is_instance_valid(profile):
		return false
	var upgrades: Dictionary = profile.upgrades
	return _execute("""
		INSERT INTO %s (account_id, gold, damage, health, speed, duration, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, unixepoch())
		ON CONFLICT(account_id) DO UPDATE SET
			gold = excluded.gold,
			damage = excluded.damage,
			health = excluded.health,
			speed = excluded.speed,
			duration = excluded.duration,
			updated_at = unixepoch();
	""" % TABLE_NAME, [account_id, profile.gold, int(upgrades.get("damage", 0)), int(upgrades.get("health", 0)), int(upgrades.get("speed", 0)), int(upgrades.get("duration", 0))])

func close() -> void:
	if _database != null:
		_database.call("close_db")
	_database = null
	_ready = false

func _execute(statement: String, bindings: Array = []) -> bool:
	var succeeded: bool
	if bindings.is_empty():
		succeeded = bool(_database.call("query", statement))
	else:
		succeeded = bool(_database.call("query_with_bindings", statement, bindings))
	if not succeeded:
		push_error("Error SQLite: %s" % String(_database.get("error_message")))
	return succeeded
