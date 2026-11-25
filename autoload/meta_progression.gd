extends Node

signal profile_changed

const SAVE_PATH: String = "user://account_profile.json"
const TEMP_PATH: String = "user://account_profile.tmp"
const BACKUP_PATH: String = "user://account_profile.bak"
const SAVE_VERSION: int = 1
const MAX_LEVEL: int = 10
const CHECKSUM_SALT: String = "HordasLocalSaveV1"
const ACCOUNT_PROFILE_SCRIPT: Script = preload("res://autoload/account_profile.gd")
const SQLITE_STORE_SCRIPT: Script = preload("res://autoload/sqlite_profile_store.gd")
const ACCOUNT_ID_PATH: String = "user://account_id.txt"

var _profile: AccountProfile = ACCOUNT_PROFILE_SCRIPT.new() as AccountProfile
var _profile_store: ProfileStore
var _account_id: String = ""

var gold: int:
	get:
		return _profile.gold if is_instance_valid(_profile) else 0
	set(value):
		if is_instance_valid(_profile):
			_profile.gold = clampi(value, 0, 2_000_000_000)

var upgrades: Dictionary:
	get:
		return _profile.upgrades if is_instance_valid(_profile) else {}
	set(value):
		if is_instance_valid(_profile):
			_profile.upgrades = value.duplicate(true)

func _ready() -> void:
	_account_id = _load_or_create_account_id()
	_profile_store = SQLITE_STORE_SCRIPT.new() as SqliteProfileStore
	if not _profile_store.open():
		_profile_store = null
	load_profile()

func _exit_tree() -> void:
	if is_instance_valid(_profile_store):
		_profile_store.close()

func load_profile() -> void:
	if is_instance_valid(_profile_store):
		var database_data: Dictionary = _profile_store.load_profile(_account_id)
		if not database_data.is_empty():
			var database_profile: AccountProfile = ACCOUNT_PROFILE_SCRIPT.new() as AccountProfile
			if database_profile.load_save_dictionary(database_data, MAX_LEVEL):
				_profile = database_profile
				profile_changed.emit()
				return
		# Importa una sola vez las partidas guardadas en JSON por versiones anteriores.
		if _load_profile_from(SAVE_PATH) or _load_profile_from(BACKUP_PATH):
			_save_profile()
			profile_changed.emit()
			return
		_reset_profile()
		return
	var loaded: bool = _load_profile_from(SAVE_PATH)
	if not loaded:
		loaded = _load_profile_from(BACKUP_PATH)
		if loaded:
			_save_profile()
	if not loaded:
		_reset_profile()
		return
	profile_changed.emit()

func _load_profile_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return false
	var data: Dictionary = parsed as Dictionary
	var checksum: String = String(data.get("checksum", ""))
	var unsigned: Dictionary = data.duplicate(true)
	unsigned.erase("checksum")
	if int(data.get("version", -1)) != SAVE_VERSION or checksum != _checksum(unsigned):
		return false
	var loaded_profile: AccountProfile = ACCOUNT_PROFILE_SCRIPT.new() as AccountProfile
	if not loaded_profile.load_save_dictionary(unsigned, MAX_LEVEL):
		return false
	_profile = loaded_profile
	return true

func get_upgrade_level(upgrade_id: String) -> int:
	return clampi(int(upgrades.get(upgrade_id, 0)), 0, MAX_LEVEL)

func cost_for(upgrade_id: String) -> int:
	var level: int = get_upgrade_level(upgrade_id)
	return 50 + level * 40

func purchase(upgrade_id: String) -> bool:
	if not upgrades.has(upgrade_id):
		return false
	var level: int = get_upgrade_level(upgrade_id)
	var cost: int = cost_for(upgrade_id)
	if level >= MAX_LEVEL or gold < cost:
		return false
	gold -= cost
	upgrades[upgrade_id] = level + 1
	_save_profile()
	profile_changed.emit()
	return true

func get_upgrade_levels() -> Dictionary:
	return {
		"damage": get_upgrade_level("damage"),
		"health": get_upgrade_level("health"),
		"speed": get_upgrade_level("speed"),
		"duration": get_upgrade_level("duration")
	}

func apply_profile_to_player(player: Player, profile: Dictionary = {}) -> void:
	var levels: Dictionary = get_upgrade_levels() if profile.is_empty() else profile
	var damage_bonus: float = float(clampi(int(levels.get("damage", 0)), 0, MAX_LEVEL)) * 0.04
	var health_bonus: float = float(clampi(int(levels.get("health", 0)), 0, MAX_LEVEL)) * 0.06
	var speed_bonus: float = float(clampi(int(levels.get("speed", 0)), 0, MAX_LEVEL)) * 0.025
	var duration_bonus: float = float(clampi(int(levels.get("duration", 0)), 0, MAX_LEVEL)) * 0.04
	player.initial_health *= 1.0 + health_bonus
	player.replicated_weapon_damage *= 1.0 + damage_bonus
	player.replicated_move_speed *= 1.0 + speed_bonus
	player.replicated_ultimate_duration_bonus = duration_bonus

func award_run(amount: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (not multiplayer.is_server() and sender_id != 1) or amount <= 0:
		return
	gold += amount
	_save_profile()
	profile_changed.emit()

func _reset_profile() -> void:
	_profile = ACCOUNT_PROFILE_SCRIPT.new() as AccountProfile
	_save_profile()
	profile_changed.emit()

func _save_profile() -> void:
	if is_instance_valid(_profile_store):
		if not _profile_store.save_profile(_account_id, _profile):
			push_error("No se pudo guardar el perfil en SQLite.")
		return
	# Respaldo compatible si la extensión SQLite no se cargó en este sistema.
	var data: Dictionary = _profile.to_save_dictionary()
	data["checksum"] = _checksum(data)
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	var absolute_save: String = ProjectSettings.globalize_path(SAVE_PATH)
	var absolute_temp: String = ProjectSettings.globalize_path(TEMP_PATH)
	var absolute_backup: String = ProjectSettings.globalize_path(BACKUP_PATH)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(absolute_backup)
		if DirAccess.rename_absolute(absolute_save, absolute_backup) != OK:
			return
	if DirAccess.rename_absolute(absolute_temp, absolute_save) != OK:
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return
	DirAccess.remove_absolute(absolute_backup)

func _load_or_create_account_id() -> String:
	if FileAccess.file_exists(ACCOUNT_ID_PATH):
		var id_file: FileAccess = FileAccess.open(ACCOUNT_ID_PATH, FileAccess.READ)
		if id_file != null:
			var existing_id: String = id_file.get_as_text().strip_edges()
			id_file.close()
			if existing_id.length() >= 32:
				return existing_id
	var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	var account_id: String = random_bytes.hex_encode()
	var id_file: FileAccess = FileAccess.open(ACCOUNT_ID_PATH, FileAccess.WRITE)
	if id_file != null:
		id_file.store_string(account_id)
		id_file.close()
	return account_id

func _checksum(data: Dictionary) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(CHECKSUM_SALT.to_utf8_buffer())
	context.update(JSON.stringify(data).to_utf8_buffer())
	return context.finish().hex_encode()

