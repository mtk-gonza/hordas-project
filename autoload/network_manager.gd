extends Node

signal status_changed(message: String)
signal lobby_changed()

const DEFAULT_PORT: int = 2456
const MAX_REMOTE_PEERS: int = 3
const CHARACTER_IDS: Array[StringName] = [&"warden", &"stormcaller", &"moonkeeper", &"grovekeeper"]
const MAIN_MENU_PATH: String = "res://scenes/menus/main_menu.tscn"
const GAME_WORLD_PATH: String = "res://scenes/session/game_world.tscn"

var _peer: ENetMultiplayerPeer
var _world: Node
var _world_ready_peers: Dictionary = {}
var _upgrade_profiles_by_peer: Dictionary = {}
var _character_by_peer: Dictionary = {}
var _local_character_id: StringName = &"warden"
var selected_map_id: StringName = &"neon_district"
var _roster_spawned: bool = false
var _session_started: bool = false
var _dedicated_mode: bool = false
var _dedicated_start_countdown: float = 15.0
var _local_game_paused: bool = false

func _ready() -> void:
	_ensure_input_actions()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_parse_dedicated_arguments()

func _process(delta: float) -> void:
	if not _dedicated_mode or not multiplayer.is_server() or _session_started:
		return
	if multiplayer.get_peers().is_empty():
		return
	_dedicated_start_countdown -= delta
	if _dedicated_start_countdown <= 0.0:
		start_run()

func host_game(port: int = DEFAULT_PORT) -> Error:
	if port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	_close_peer()
	_reset_session_state()
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_server(port, MAX_REMOTE_PEERS)
	if error != OK:
		_peer = null
		status_changed.emit("No se pudo abrir UDP %d (error %d)." % [port, error])
		return error
	multiplayer.multiplayer_peer = _peer
	_reset_session_state()
	_upgrade_profiles_by_peer[1] = MetaProgression.get_upgrade_levels()
	_character_by_peer[1] = _local_character_id
	status_changed.emit("Sala creada en UDP %d. Comparte tu IP y espera a tus compañeros." % port)
	lobby_changed.emit()
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var normalized_address: String = address.strip_edges()
	if normalized_address.is_empty() or port < 1 or port > 65535:
		return ERR_INVALID_PARAMETER
	_close_peer()
	_reset_session_state()
	_peer = ENetMultiplayerPeer.new()
	var error: Error = _peer.create_client(normalized_address, port)
	if error != OK:
		_peer = null
		status_changed.emit("No se pudo iniciar la conexión (error %d)." % error)
		return error
	multiplayer.multiplayer_peer = _peer
	status_changed.emit("Conectando a %s:%d…" % [normalized_address, port])
	return OK

func start_run() -> void:
	if not multiplayer.is_server() or _session_started:
		return
	_session_started = true
	_world_ready_peers.clear()
	_roster_spawned = false
	_start_game_scene.rpc(String(selected_map_id))

func restart_run() -> void:
	if multiplayer.is_server():
		_restart_game_scene.rpc(String(selected_map_id))
	else:
		_request_restart_run.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _request_restart_run() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(sender_id):
		return
	_restart_game_scene.rpc(String(selected_map_id))

@rpc("authority", "call_local", "reliable")
func _restart_game_scene(map_id: String) -> void:
	selected_map_id = GameMapCatalog.sanitize(StringName(map_id))
	_session_started = true
	_world = null
	_world_ready_peers.clear()
	_roster_spawned = false
	get_tree().change_scene_to_file(GAME_WORLD_PATH)

@rpc("authority", "call_local", "reliable")
func _start_game_scene(map_id: String) -> void:
	selected_map_id = GameMapCatalog.sanitize(StringName(map_id))
	_session_started = true
	get_tree().change_scene_to_file(GAME_WORLD_PATH)

func register_world(world: Node) -> void:
	if not _session_started:
		return
	if multiplayer.is_server():
		_world = world
		_world_ready_peers[1] = true
		_try_spawn_initial_roster()
	else:
		_report_world_ready.rpc_id(1, MetaProgression.get_upgrade_levels(), String(_local_character_id))

@rpc("any_peer", "call_remote", "reliable")
func _report_world_ready(upgrade_levels: Dictionary, character_id: String) -> void:
	if not multiplayer.is_server() or not _session_started:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(sender_id):
		return
	_upgrade_profiles_by_peer[sender_id] = _sanitize_upgrade_profile(upgrade_levels)
	_character_by_peer[sender_id] = _sanitize_character_id(StringName(character_id))
	_world_ready_peers[sender_id] = true
	_try_spawn_initial_roster()

func get_upgrade_profile(peer_id: int) -> Dictionary:
	return (_upgrade_profiles_by_peer.get(peer_id, {"damage": 0, "health": 0, "speed": 0, "duration": 0}) as Dictionary).duplicate(true)

func get_character_for_peer(peer_id: int) -> StringName:
	return _sanitize_character_id(StringName(_character_by_peer.get(peer_id, &"warden")))

func get_local_character_id() -> StringName:
	return _local_character_id

func set_local_character_id(character_id: StringName) -> void:
	_local_character_id = _sanitize_character_id(character_id)
	if multiplayer.is_server():
		_character_by_peer[1] = _local_character_id

func set_selected_map_id(map_id: StringName) -> void:
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	selected_map_id = GameMapCatalog.sanitize(map_id)
	if is_session_host():
		_replicate_lobby_map.rpc(String(selected_map_id))
	else:
		lobby_changed.emit()

@rpc("authority", "call_local", "reliable")
func _replicate_lobby_map(map_id: String) -> void:
	selected_map_id = GameMapCatalog.sanitize(StringName(map_id))
	lobby_changed.emit()

func _sanitize_character_id(character_id: StringName) -> StringName:
	return character_id if CHARACTER_IDS.has(character_id) else &"warden"

func _sanitize_upgrade_profile(profile: Dictionary) -> Dictionary:
	var sanitized: Dictionary = {}
	for upgrade_id: String in ["damage", "health", "speed", "duration"]:
		sanitized[upgrade_id] = clampi(int(profile.get(upgrade_id, 0)), 0, MetaProgression.MAX_LEVEL)
	return sanitized

func _try_spawn_initial_roster() -> void:
	if not multiplayer.is_server() or _roster_spawned or not is_instance_valid(_world):
		return
	var expected_ids: Array[int] = []
	if not _dedicated_mode:
		expected_ids.append(1)
	for peer_id: int in multiplayer.get_peers():
		expected_ids.append(peer_id)
	if expected_ids.is_empty():
		return
	for peer_id: int in expected_ids:
		if not _world_ready_peers.has(peer_id):
			return
	_roster_spawned = true
	expected_ids.sort()
	_world.call("enable_world_synchronization")
	for peer_id: int in expected_ids:
		_world.call("spawn_player", peer_id, get_character_for_peer(peer_id))
	status_changed.emit("Partida iniciada con %d jugador(es)." % expected_ids.size())

func leave_session() -> void:
	_close_peer()
	_reset_session_state()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
	status_changed.emit("Sesión cerrada.")
	lobby_changed.emit()

func is_session_host() -> bool:
	return multiplayer.is_server() and multiplayer.multiplayer_peer is ENetMultiplayerPeer and not _dedicated_mode

func is_dedicated_mode() -> bool:
	return _dedicated_mode

func set_local_game_paused(paused: bool) -> void:
	_local_game_paused = paused

func is_local_game_paused() -> bool:
	return _local_game_paused

func get_player_ids() -> Array[int]:
	var result: Array[int] = []
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return result
	if multiplayer.is_server() and not _dedicated_mode:
		result.append(1)
	elif not multiplayer.is_server():
		result.append(multiplayer.get_unique_id())
	for peer_id: int in multiplayer.get_peers():
		if not result.has(peer_id):
			result.append(peer_id)
	result.sort()
	return result

func _close_peer() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	if _peer != null:
		_peer.close()
		_peer = null

func _reset_session_state() -> void:
	_world = null
	_world_ready_peers.clear()
	_upgrade_profiles_by_peer.clear()
	_character_by_peer.clear()
	_roster_spawned = false
	_session_started = false
	_local_game_paused = false

func _on_peer_connected(peer_id: int) -> void:
	if _session_started and multiplayer.is_server():
		var enet: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if enet != null:
			enet.disconnect_peer(peer_id)
			status_changed.emit("Sala cerrada: no se permiten uniones con la partida iniciada.")
		return
	_replicate_lobby_map.rpc_id(peer_id, String(selected_map_id))
	lobby_changed.emit()
	status_changed.emit("Se conectó el jugador %d." % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_world_ready_peers.erase(peer_id)
	if multiplayer.is_server() and is_instance_valid(_world) and _roster_spawned:
		_world.call("despawn_player", peer_id)
	if multiplayer.is_server() and _session_started and not _roster_spawned:
		_try_spawn_initial_roster()
	lobby_changed.emit()
	status_changed.emit("Se desconectó el jugador %d." % peer_id)

func _on_connected_to_server() -> void:
	status_changed.emit("Conectado al host. Esperando que inicie la partida…")
	lobby_changed.emit()

func _on_connection_failed() -> void:
	status_changed.emit("Falló la conexión. Revisa IP, puerto UDP y firewall.")
	_close_peer()
	_reset_session_state()
	lobby_changed.emit()

func _on_server_disconnected() -> void:
	_close_peer()
	_reset_session_state()
	status_changed.emit("El host cerró la sesión.")
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
	lobby_changed.emit()

func _ensure_input_actions() -> void:
	_add_key_action(&"move_left", KEY_A)
	_add_key_action(&"move_left", KEY_LEFT)
	_add_key_action(&"move_right", KEY_D)
	_add_key_action(&"move_right", KEY_RIGHT)
	_add_key_action(&"move_up", KEY_W)
	_add_key_action(&"move_up", KEY_UP)
	_add_key_action(&"move_down", KEY_S)
	_add_key_action(&"move_down", KEY_DOWN)
	_add_joypad_axis_action(&"move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joypad_axis_action(&"move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joypad_axis_action(&"move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joypad_axis_action(&"move_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_key_action(&"attack", KEY_SPACE)
	_add_joypad_button_action(&"attack", JOY_BUTTON_A)
	_add_key_action(&"interact", KEY_F)
	_add_joypad_button_action(&"interact", JOY_BUTTON_X)
	_add_key_action(&"character_skill", KEY_E)
	_add_joypad_button_action(&"character_skill", JOY_BUTTON_B)
	_add_key_action(&"ultimate", KEY_R)
	_add_joypad_button_action(&"ultimate", JOY_BUTTON_Y)
	_add_key_action(&"leave", KEY_ESCAPE)
	_add_joypad_button_action(&"leave", JOY_BUTTON_START)

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return
	var key_event: InputEventKey = InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)

func _add_joypad_button_action(action: StringName, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return
	var button_event: InputEventJoypadButton = InputEventJoypadButton.new()
	button_event.button_index = button_index
	InputMap.action_add_event(action, button_event)

func _add_joypad_axis_action(action: StringName, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion:
			var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, axis_value):
				return
	var motion_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion_event.axis = axis
	motion_event.axis_value = axis_value
	InputMap.action_add_event(action, motion_event)

func _parse_dedicated_arguments() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_dedicated_mode = args.has("--dedicated")
	if not _dedicated_mode:
		return
	var port: int = DEFAULT_PORT
	for arg: String in args:
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	var error: Error = host_game(port)
	if error != OK:
		push_error("No se pudo iniciar servidor dedicado: %d" % error)
	else:
		status_changed.emit("Servidor dedicado. Inicia en 15 s después de conectar el primer cliente.")
