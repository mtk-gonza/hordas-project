extends Node2D
class_name GameWorld

const PLAYER_SCENE: PackedScene = preload("res://features/player/player.tscn")
const SHARED_CAMERA_SCRIPT: Script = preload("res://features/session/shared_camera.gd")

@export var arena_radius: float = 1150.0

@onready var _player_spawner: MultiplayerSpawner = $PlayerSpawner
@onready var _enemy_spawner: EnemySpawner = $EnemySpawner
@onready var objective_manager: ObjectiveManager = $ObjectiveManager
@onready var _hud: GameHUD = get_node_or_null("HUD") as GameHUD
var _world_synchronizer: MultiplayerSynchronizer

var elapsed_seconds: float = 0.0
var alive_enemy_count: int = 0
var game_over: bool = false
var run_result: StringName = &""
var run_reward: int = 0
var run_kills: int = 0
var team_level: int = 1
var team_xp: int = 0
var team_xp_to_next: int = 240
var _players_by_peer: Dictionary = {}
var _revive_target_by_reviver: Dictionary = {}
var _revive_claim_time_by_reviver: Dictionary = {}
var _world_replication_config: SceneReplicationConfig
var _reward_awarded: bool = false
const REVIVE_CLAIM_LEASE_MSEC: int = 450

func _ready() -> void:
	add_to_group("session_world")
	if not NetworkManager.is_dedicated_mode():
		_create_arena_floor()
		_create_shared_camera()
	_player_spawner.spawn_path = NodePath("../Actors")
	_player_spawner.spawn_function = _make_player
	_enemy_spawner.boss_defeated.connect(_on_boss_defeated)
	_configure_world_synchronizer()
	NetworkManager.register_world(self)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or game_over:
		return
	elapsed_seconds += delta
	_process_wave_respawns()
	alive_enemy_count = _enemy_spawner.get_alive_count()
	var live_players: int = 0
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and not player.replicated_dead:
			live_players += 1
	if live_players == 0 and not _players_by_peer.is_empty() and not _has_pending_respawns():
		_run_ended.rpc(&"defeat", _calculate_run_reward(false), _enemy_spawner.total_kills)

func _process_wave_respawns() -> void:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player == null or not player.can_respawn_at(elapsed_seconds):
			continue
		player.respawn_at_wave(_team_respawn_position(player.peer_id))

func _has_pending_respawns() -> bool:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.replicated_dead and player.replicated_respawn_at >= elapsed_seconds and player.replicated_respawn_at >= 0.0:
			return true
	return false

func _team_respawn_position(peer_id: int) -> Vector2:
	var center: Vector2 = Vector2.ZERO
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("players"):
		var ally: Player = node as Player
		if ally == null or ally.replicated_dead or ally.replicated_downed or ally.replicated_health <= 0.0:
			continue
		center += ally.global_position
		count += 1
	if count > 0:
		center /= float(count)
	var offset: Vector2 = Vector2.RIGHT.rotated(float(peer_id) * TAU / 4.0) * 72.0
	return (center + offset).limit_length(arena_radius - 32.0)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("leave") and is_instance_valid(_hud):
		_hud.toggle_pause()

func spawn_player(peer_id: int, character_id: StringName) -> void:
	if not multiplayer.is_server() or _players_by_peer.has(peer_id):
		return
	_player_spawner.spawn({"peer_id": peer_id, "character_id": String(character_id)})

func despawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player: Player = _players_by_peer.get(peer_id) as Player
	if is_instance_valid(player):
		_players_by_peer.erase(peer_id)
		player.queue_free()

func _make_player(data: Variant) -> Node:
	var payload: Dictionary = data as Dictionary
	var peer_id: int = int(payload.get("peer_id", -1))
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.name = "Player_%d" % peer_id
	player.peer_id = peer_id
	player.character_id = StringName(payload.get("character_id", "warden"))
	player.position = _spawn_position_for(peer_id)
	player.set_multiplayer_authority(1, true)
	MetaProgression.apply_profile_to_player(player, NetworkManager.get_upgrade_profile(peer_id))
	_players_by_peer[peer_id] = player
	return player

func _spawn_position_for(peer_id: int) -> Vector2:
	var angle: float = float(peer_id - 1) * TAU / 4.0
	return Vector2.RIGHT.rotated(angle) * 72.0

func _configure_world_synchronizer() -> void:
	_world_synchronizer = MultiplayerSynchronizer.new()
	_world_synchronizer.name = "WorldSynchronizer"
	_world_synchronizer.root_path = NodePath("..")
	_world_synchronizer.replication_interval = 0.1
	_world_synchronizer.delta_interval = 0.1
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	_add_sync_property(config, ".:elapsed_seconds", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:alive_enemy_count", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:game_over", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:run_result", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:run_reward", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:run_kills", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:team_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:team_xp", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:team_xp_to_next", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_world_replication_config = config

func enable_world_synchronization() -> void:
	if multiplayer.is_server():
		_enable_world_synchronization.rpc()

@rpc("authority", "call_local", "reliable")
func _enable_world_synchronization() -> void:
	if is_instance_valid(_world_synchronizer) and not _world_synchronizer.is_inside_tree():
		_world_synchronizer.replication_config = _world_replication_config
		add_child(_world_synchronizer)

func _add_sync_property(config: SceneReplicationConfig, path_text: String, mode: int) -> void:
	var path: NodePath = NodePath(path_text)
	config.add_property(path)
	config.property_set_replication_mode(path, mode)
	config.property_set_spawn(path, true)

func _on_boss_defeated() -> void:
	if multiplayer.is_server() and not game_over:
		_run_ended.rpc(&"victory", _calculate_run_reward(true), _enemy_spawner.total_kills)

@rpc("authority", "call_local", "reliable")
func _run_ended(result: StringName, reward: int, kills: int) -> void:
	game_over = true
	run_result = result
	run_reward = reward
	run_kills = kills
	if not _reward_awarded:
		_reward_awarded = true
		MetaProgression.award_run(reward)
	_enemy_spawner.set_physics_process(false)
	_enemy_spawner.set_process(false)

func _calculate_run_reward(victory: bool) -> int:
	var reward: int = 80 + floori(elapsed_seconds * 1.5) + _enemy_spawner.total_kills * 3
	if is_instance_valid(objective_manager):
		reward += objective_manager.bonus_gold
	if victory:
		reward += 250
	return reward

func grant_team_xp(amount: int) -> void:
	if not multiplayer.is_server() or amount <= 0 or game_over:
		return
	team_xp += amount
	while team_xp >= team_xp_to_next:
		team_xp -= team_xp_to_next
		team_level += 1
		team_xp_to_next = 240 + (team_level - 1) * 85
		for node: Node in get_tree().get_nodes_in_group("players"):
			var player: Player = node as Player
			if player != null:
				player.grant_shared_upgrade_token()

func get_local_player() -> Player:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.peer_id == multiplayer.get_unique_id():
			return player
	return null

func try_claim_revive(reviver_peer_id: int, target_peer_id: int) -> bool:
	if not multiplayer.is_server() or reviver_peer_id == target_peer_id:
		return false
	var now: int = Time.get_ticks_msec()
	_expire_revive_claims(now)
	var current_target: int = int(_revive_target_by_reviver.get(reviver_peer_id, -1))
	var current_time: int = int(_revive_claim_time_by_reviver.get(reviver_peer_id, 0))
	if current_target >= 0 and current_target != target_peer_id and now - current_time < REVIVE_CLAIM_LEASE_MSEC:
		return false
	for raw_reviver_id: Variant in _revive_target_by_reviver.keys():
		var other_reviver_id: int = int(raw_reviver_id)
		if other_reviver_id == reviver_peer_id or int(_revive_target_by_reviver[raw_reviver_id]) != target_peer_id:
			continue
		var other_claim_time: int = int(_revive_claim_time_by_reviver.get(other_reviver_id, 0))
		if now - other_claim_time < REVIVE_CLAIM_LEASE_MSEC:
			return false
		_release_revive_claim_for_reviver(other_reviver_id)
	_revive_target_by_reviver[reviver_peer_id] = target_peer_id
	_revive_claim_time_by_reviver[reviver_peer_id] = now
	return true

func release_revive_claim_for_target(target_peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	for raw_reviver_id: Variant in _revive_target_by_reviver.keys():
		var reviver_peer_id: int = int(raw_reviver_id)
		if int(_revive_target_by_reviver[raw_reviver_id]) == target_peer_id:
			_release_revive_claim_for_reviver(reviver_peer_id)

func _expire_revive_claims(now: int) -> void:
	for raw_reviver_id: Variant in _revive_claim_time_by_reviver.keys():
		var reviver_peer_id: int = int(raw_reviver_id)
		if now - int(_revive_claim_time_by_reviver[raw_reviver_id]) >= REVIVE_CLAIM_LEASE_MSEC:
			_release_revive_claim_for_reviver(reviver_peer_id)

func _release_revive_claim_for_reviver(reviver_peer_id: int) -> void:
	_revive_target_by_reviver.erase(reviver_peer_id)
	_revive_claim_time_by_reviver.erase(reviver_peer_id)

func is_boss_active() -> bool:
	return _enemy_spawner.boss_active

func get_boss_health_ratio() -> float:
	return _enemy_spawner.boss_health_ratio

func spawn_access_card(position: Vector2) -> void:
	if is_instance_valid(objective_manager):
		objective_manager.spawn_access_card(position)

func constrain_to_battle_circle(player: Player, desired_position: Vector2) -> Vector2:
	var allies: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		var ally: Player = node as Player
		if ally != null and ally != player and not ally.replicated_downed and not ally.replicated_dead and ally.replicated_health > 0.0:
			allies.append(ally)
	if allies.is_empty():
		return desired_position
	var center: Vector2 = Vector2.ZERO
	for ally: Player in allies:
		center += ally.global_position
	center /= float(allies.size())
	var offset: Vector2 = desired_position - center
	const TEAM_RADIUS: float = 520.0
	if offset.length_squared() > TEAM_RADIUS * TEAM_RADIUS:
		return center + offset.normalized() * TEAM_RADIUS
	return desired_position

func _create_shared_camera() -> void:
	var camera: Camera2D = Camera2D.new()
	camera.name = "SharedBattleCamera"
	camera.set_script(SHARED_CAMERA_SCRIPT)
	add_child(camera)

func _draw() -> void:
	var accent: Color = GameMapCatalog.accent_color(NetworkManager.selected_map_id)
	draw_arc(Vector2.ZERO, arena_radius, 0.0, TAU, 280, Color("#07131c"), 30.0, true)
	draw_arc(Vector2.ZERO, arena_radius - 22.0, 0.0, TAU, 280, accent.lightened(0.08), 2.0, true)
	draw_arc(Vector2.ZERO, arena_radius - 36.0, 0.0, TAU, 280, accent.darkened(0.15), 1.0, true)

func _create_arena_floor() -> void:
	var floor: TextureRect = TextureRect.new()
	floor.name = "CryptArena"
	floor.texture = load(GameMapCatalog.background_path(NetworkManager.selected_map_id)) as Texture2D
	floor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor.stretch_mode = TextureRect.STRETCH_SCALE
	floor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor.modulate = Color(0.96, 0.97, 1.0, 1.0)
	floor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floor.position = Vector2(-arena_radius, -arena_radius)
	floor.size = Vector2.ONE * arena_radius * 2.0
	floor.z_index = -100
	add_child(floor)
	move_child(floor, 0)
