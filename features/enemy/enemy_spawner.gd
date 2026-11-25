extends Node
class_name EnemySpawner

signal boss_defeated

const ENEMY_SCENE: PackedScene = preload("res://features/enemy/base_enemy.tscn")
const DEFAULT_WAVE_SET: WaveSet = preload("res://features/enemy/wave_set.tres")
const CELL_SIZE: float = 48.0
const AI_STEP: float = 1.0 / 30.0
const INTERPOLATION_DELAY: float = 0.12
const MAX_EXTRAPOLATION: float = 0.12
const INITIAL_WAVE_COUNT: int = 6
const INITIAL_WAVE_DELAY: float = 1.5
const SPECIES_BY_ARCHETYPE: Dictionary = {
	&"base": [&"kobold_miner", &"jackalope", &"mimic_jar"],
	&"warrior": [&"antlion", &"gargoyle", &"rock_crab"],
	&"rogue": [&"bat_swarm", &"roller_bug", &"shadow_cat", &"ratfolk_thief"],
	&"mage": [&"crystal_cube", &"flame_skull", &"frost_moth", &"wraith"],
	&"soul_weaver": [&"jelly", &"thorn_sprite", &"wraith"],
	&"storm_mage": [&"giant_mosquito", &"frost_moth", &"flame_skull"],
	&"bone_archer": [&"mummy_cat", &"wraith"],
	&"plague_brute": [&"magma_slug", &"rock_crab", &"antlion"]
}
const MINIBOSS_SPECIES_BY_ARCHETYPE: Dictionary = {
	&"base": [&"gargoyle", &"mimic_jar"],
	&"warrior": [&"gargoyle", &"rock_crab"],
	&"rogue": [&"shadow_cat", &"bat_swarm"],
	&"mage": [&"crystal_cube", &"flame_skull"],
	&"soul_weaver": [&"thorn_sprite", &"jelly"],
	&"storm_mage": [&"giant_mosquito", &"frost_moth"],
	&"bone_archer": [&"mummy_cat", &"wraith"],
	&"plague_brute": [&"magma_slug", &"antlion"]
}
const SPECIES_BY_ELITE_MODIFIER: Dictionary = {
	1: [&"gargoyle", &"rock_crab", &"crystal_cube"],
	2: [&"goblin_bomber"],
	3: [&"jelly", &"thorn_sprite"]
}
const BOSS_SPECIES: Array[StringName] = [&"elder_treant", &"gel_monarch", &"dragon_whelp", &"bone_archmage", &"tide_kraken", &"golem_king"]

@export var wave_set: WaveSet = DEFAULT_WAVE_SET
@export var snapshot_interval: float = 0.1

@onready var _network_spawner: MultiplayerSpawner = $MultiplayerSpawner

var elapsed: float = 0.0
var total_kills: int = 0
var _spawn_credit: float = 0.0
var _snapshot_credit: float = 0.0
var _ai_credit: float = 0.0
var _next_net_id: int = 1
var _boss_spawned: bool = false
var _initial_wave_spawned: bool = false
var _next_miniboss_time: float = 90.0
var _boss_net_id: int = -1
var boss_active: bool = false
var boss_health_ratio: float = 0.0
var _enrage_time_left: float = 0.0
var _enrage_multiplier: float = 1.0
var _enemies: Dictionary = {} # net_id -> BaseEnemy
var _snapshot_history: Dictionary = {} # net_id -> [{time, position}, ...]
var _spatial_cells: Dictionary = {} # Vector2i -> Array[BaseEnemy]
var _players: Array[Player] = []

func _ready() -> void:
	_next_miniboss_time = GameMapCatalog.miniboss_interval(NetworkManager.selected_map_id)
	_network_spawner.spawn_limit = wave_set.maximum_enemies
	_network_spawner.spawn_path = NodePath("../../Actors")
	_network_spawner.spawn_function = _make_enemy
	_network_spawner.despawned.connect(_on_enemy_despawned)
	set_process(not multiplayer.is_server())

func _process(_delta: float) -> void:
	if multiplayer.is_server():
		return
	var render_time: float = float(Time.get_ticks_msec()) / 1000.0 - INTERPOLATION_DELAY
	for raw_id: Variant in _snapshot_history.keys():
		var net_id: int = int(raw_id)
		var enemy: BaseEnemy = _enemies.get(net_id) as BaseEnemy
		var history: Array = _snapshot_history[net_id]
		if not is_instance_valid(enemy) or history.is_empty():
			continue
		var latest: Dictionary = history[history.size() - 1]
		if history.size() == 1:
			enemy.global_position = latest["position"]
			continue
		var previous: Dictionary = history[history.size() - 2]
		var previous_time: float = float(previous["time"])
		var latest_time: float = float(latest["time"])
		var previous_position: Vector2 = previous["position"]
		var latest_position: Vector2 = latest["position"]
		var interval: float = latest_time - previous_time
		if interval <= 0.0001:
			enemy.global_position = latest_position
		elif render_time <= previous_time:
			enemy.global_position = previous_position
		elif render_time <= latest_time:
			var blend: float = (render_time - previous_time) / interval
			enemy.global_position = previous_position.lerp(latest_position, blend)
		else:
			var extrapolation: float = minf(render_time - latest_time, MAX_EXTRAPOLATION)
			var velocity: Vector2 = (latest_position - previous_position) / interval
			enemy.global_position = latest_position + velocity * extrapolation

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	elapsed += delta
	_enrage_time_left = maxf(0.0, _enrage_time_left - delta)
	if _enrage_time_left <= 0.0 and _enrage_multiplier > 1.0:
		_enrage_multiplier = 1.0
		_replicate_enrage.rpc(0.0, 1.0)
		for enemy_node: Variant in _enemies.values():
			var current_enemy: BaseEnemy = enemy_node as BaseEnemy
			if is_instance_valid(current_enemy):
				current_enemy.set_enraged(1.0)
	_spawn_wave_entities(delta)
	_ai_credit += delta
	if _ai_credit >= AI_STEP:
		var ai_delta: float = _ai_credit
		_ai_credit = 0.0
		_players = _live_players()
		_rebuild_spatial_grid()
		for node: Variant in _enemies.values():
			var enemy: BaseEnemy = node as BaseEnemy
			if not is_instance_valid(enemy) or not enemy.alive:
				continue
			var target: Player = _nearest_player(enemy.global_position)
			if target != null:
				enemy.server_tick(ai_delta, target, _neighbors(enemy.global_position))
	_snapshot_credit += delta
	if _snapshot_credit >= snapshot_interval:
		_snapshot_credit = fmod(_snapshot_credit, snapshot_interval)
		_send_snapshots()

func get_alive_count() -> int:
	var count: int = 0
	for node: Variant in _enemies.values():
		var enemy: BaseEnemy = node as BaseEnemy
		if is_instance_valid(enemy) and enemy.alive:
			count += 1
	return count

func apply_horde_enrage(duration: float) -> void:
	if not multiplayer.is_server():
		return
	_enrage_time_left = maxf(_enrage_time_left, duration)
	_enrage_multiplier = 1.32
	for enemy_node: Variant in _enemies.values():
		var enemy: BaseEnemy = enemy_node as BaseEnemy
		if is_instance_valid(enemy) and enemy.alive:
			enemy.set_enraged(_enrage_multiplier)
	_replicate_enrage.rpc(_enrage_time_left, _enrage_multiplier)

func _spawn_wave_entities(delta: float) -> void:
	if not _initial_wave_spawned and elapsed >= INITIAL_WAVE_DELAY:
		_initial_wave_spawned = true
		for _index: int in range(INITIAL_WAVE_COUNT):
			_spawn_enemy(false)
	if elapsed >= _next_miniboss_time and elapsed < wave_set.boss_time_seconds and _enemies.size() < wave_set.maximum_enemies:
		_spawn_enemy(false, true)
		_next_miniboss_time += GameMapCatalog.miniboss_interval(NetworkManager.selected_map_id)
	var minute: int = int(floor(elapsed / 60.0))
	var rate: float = (wave_set.first_minute_rate + float(minute) * wave_set.additional_per_minute) * GameMapCatalog.spawn_rate_multiplier(NetworkManager.selected_map_id)
	_spawn_credit += rate / 60.0 * delta
	while _spawn_credit >= 1.0:
		_spawn_credit -= 1.0
		if _enemies.size() < wave_set.maximum_enemies:
			_spawn_enemy(false)
	if not _boss_spawned and elapsed >= wave_set.boss_time_seconds and _enemies.size() < wave_set.maximum_enemies:
		_boss_spawned = true
		_spawn_enemy(true)

func _spawn_enemy(boss: bool, miniboss: bool = false) -> void:
	var net_id: int = _next_net_id
	_next_net_id += 1
	if boss:
		_boss_net_id = net_id
	var center: Vector2 = _party_center()
	var spawn_position: Vector2 = center + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * wave_set.spawn_radius
	var archetype: StringName = _archetype_for(net_id) if not boss else &"orc_boss"
	var modifier: int = _modifier_for(net_id) if not boss and not miniboss else 0
	var visual_species: StringName = _visual_species_for(archetype, net_id, boss, miniboss, modifier)
	_network_spawner.spawn({"net_id": net_id, "position": spawn_position, "boss": boss, "miniboss": miniboss, "archetype": archetype, "visual_species": visual_species, "modifier": modifier, "enrage": _enrage_multiplier})

func _visual_species_for(archetype: StringName, net_id: int, boss: bool, miniboss: bool, modifier: int) -> StringName:
	if boss:
		return BOSS_SPECIES[randi_range(0, BOSS_SPECIES.size() - 1)]
	var variants: Array = SPECIES_BY_ARCHETYPE.get(archetype, SPECIES_BY_ARCHETYPE[&"base"])
	if miniboss:
		variants = MINIBOSS_SPECIES_BY_ARCHETYPE.get(archetype, MINIBOSS_SPECIES_BY_ARCHETYPE[&"base"])
	elif SPECIES_BY_ELITE_MODIFIER.has(modifier):
		variants = SPECIES_BY_ELITE_MODIFIER[modifier]
	return StringName(variants[posmod(net_id * 7, variants.size())])

func _modifier_for(net_id: int) -> int:
	match posmod(net_id, 13):
		4:
			return 1
		7:
			return 2
		10:
			return 3
	return 0

func _archetype_for(net_id: int) -> StringName:
	match posmod(net_id, 17):
		0, 5, 8:
			return &"warrior"
		2, 7:
			return &"rogue"
		3, 12:
			return &"mage"
		6, 14:
			return &"soul_weaver"
		9:
			return &"storm_mage"
		10, 15:
			return &"bone_archer"
		11, 16:
			return &"plague_brute"
	return &"base"

func _make_enemy(data: Variant) -> Node:
	var payload: Dictionary = data
	var enemy: BaseEnemy = ENEMY_SCENE.instantiate() as BaseEnemy
	enemy.net_id = int(payload["net_id"])
	enemy.position = payload["position"]
	enemy.is_boss = bool(payload["boss"])
	enemy.is_miniboss = bool(payload.get("miniboss", false))
	enemy.archetype = StringName(payload.get("archetype", &"base"))
	enemy.visual_species = StringName(payload.get("visual_species", &""))
	enemy.elite_modifier = int(payload.get("modifier", 0))
	match enemy.archetype:
		&"warrior":
			enemy.max_health = 56.0
			enemy.move_speed = 62.0
			enemy.separation_radius = 40.0
			enemy.contact_damage = 13.0
			enemy.xp_reward = 13
		&"rogue":
			enemy.max_health = 22.0
			enemy.move_speed = 112.0
			enemy.separation_radius = 28.0
			enemy.contact_damage = 7.0
			enemy.xp_reward = 9
		&"mage":
			enemy.max_health = 34.0
			enemy.move_speed = 72.0
			enemy.separation_radius = 32.0
			enemy.contact_damage = 10.0
			enemy.xp_reward = 12
		&"soul_weaver":
			enemy.max_health = 42.0
			enemy.move_speed = 58.0
			enemy.separation_radius = 36.0
			enemy.contact_damage = 9.0
			enemy.xp_reward = 15
		&"storm_mage":
			enemy.max_health = 26.0
			enemy.move_speed = 84.0
			enemy.separation_radius = 28.0
			enemy.contact_damage = 8.0
			enemy.xp_reward = 14
		&"bone_archer":
			enemy.max_health = 25.0
			enemy.move_speed = 90.0
			enemy.separation_radius = 26.0
			enemy.contact_damage = 7.0
			enemy.xp_reward = 10
		&"plague_brute":
			enemy.max_health = 72.0
			enemy.move_speed = 48.0
			enemy.separation_radius = 48.0
			enemy.contact_damage = 16.0
			enemy.xp_reward = 16
	if enemy.is_boss:
		enemy.archetype = &"orc_boss"
		enemy.max_health = wave_set.boss_health
		enemy.move_speed = wave_set.boss_move_speed
		enemy.separation_radius = wave_set.boss_separation_radius
		enemy.xp_reward = wave_set.boss_xp_reward
		enemy.contact_damage = wave_set.boss_contact_damage
	elif enemy.is_miniboss:
		enemy.max_health = 300.0
		enemy.move_speed = 62.0
		enemy.separation_radius = 54.0
		enemy.contact_damage = 18.0
		enemy.xp_reward = 65
	var map_id: StringName = NetworkManager.selected_map_id
	enemy.max_health *= GameMapCatalog.enemy_health_multiplier(map_id)
	enemy.move_speed *= GameMapCatalog.enemy_speed_multiplier(map_id)
	_enemies[enemy.net_id] = enemy
	if not is_equal_approx(float(payload.get("enrage", 1.0)), 1.0):
		enemy.set_enraged(float(payload.get("enrage", 1.0)))
	if not multiplayer.is_server():
		_snapshot_history[enemy.net_id] = [{"time": float(Time.get_ticks_msec()) / 1000.0, "position": enemy.position}]
	enemy.died.connect(_on_enemy_died)
	enemy.despawn_ready.connect(_on_enemy_despawn_ready)
	return enemy

@rpc("authority", "call_local", "reliable")
func _replicate_enrage(duration: float, multiplier: float) -> void:
	_enrage_time_left = maxf(0.0, duration)
	_enrage_multiplier = maxf(1.0, multiplier)
	for enemy_node: Variant in _enemies.values():
		var enemy: BaseEnemy = enemy_node as BaseEnemy
		if is_instance_valid(enemy) and enemy.alive:
			enemy.set_enraged(_enrage_multiplier)

func _on_enemy_died(net_id: int, _source_peer: int) -> void:
	total_kills += 1
	var defeated_enemy: BaseEnemy = _enemies.get(net_id) as BaseEnemy
	_snapshot_history.erase(net_id)
	if net_id == _boss_net_id:
		boss_defeated.emit()
	elif is_instance_valid(defeated_enemy) and defeated_enemy.is_miniboss:
		var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
		if world != null:
			world.spawn_access_card(defeated_enemy.global_position)

func _on_enemy_despawn_ready(net_id: int) -> void:
	_enemies.erase(net_id)
	_snapshot_history.erase(net_id)

func _on_enemy_despawned(node: Node) -> void:
	var enemy: BaseEnemy = node as BaseEnemy
	if enemy != null:
		_enemies.erase(enemy.net_id)
		_snapshot_history.erase(enemy.net_id)

func _live_players() -> Array[Player]:
	var result: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.replicated_health > 0.0:
			result.append(player)
	return result

func _party_center() -> Vector2:
	if _players.is_empty():
		_players = _live_players()
	if _players.is_empty():
		return Vector2.ZERO
	var center: Vector2 = Vector2.ZERO
	for player: Player in _players:
		center += player.global_position
	return center / float(_players.size())

func _nearest_player(position: Vector2) -> Player:
	var nearest: Player
	var best_distance: float = INF
	for player: Player in _players:
		var distance: float = position.distance_squared_to(player.global_position)
		if distance < best_distance:
			best_distance = distance
			nearest = player
	return nearest

func _cell_for(position: Vector2) -> Vector2i:
	return Vector2i(floori(position.x / CELL_SIZE), floori(position.y / CELL_SIZE))

func _rebuild_spatial_grid() -> void:
	_spatial_cells.clear()
	for node: Variant in _enemies.values():
		var enemy: BaseEnemy = node as BaseEnemy
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var cell: Vector2i = _cell_for(enemy.global_position)
		if not _spatial_cells.has(cell):
			_spatial_cells[cell] = []
		var bucket: Array = _spatial_cells[cell]
		bucket.append(enemy)

func _neighbors(position: Vector2) -> Array:
	var result: Array = []
	var center: Vector2i = _cell_for(position)
	for cell_x: int in range(center.x - 1, center.x + 2):
		for cell_y: int in range(center.y - 1, center.y + 2):
			result.append_array(_spatial_cells.get(Vector2i(cell_x, cell_y), []))
	return result

func _send_snapshots() -> void:
	_sync_boss_status()
	var ids: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector2Array = PackedVector2Array()
	for node: Variant in _enemies.values():
		var enemy: BaseEnemy = node as BaseEnemy
		if is_instance_valid(enemy) and enemy.alive:
			ids.append(enemy.net_id)
			positions.append(enemy.global_position)
	var offset: int = 0
	while offset < ids.size():
		var end: int = mini(offset + 48, ids.size())
		var batch_ids: PackedInt32Array = PackedInt32Array()
		var batch_positions: PackedVector2Array = PackedVector2Array()
		for index: int in range(offset, end):
			batch_ids.append(ids[index])
			batch_positions.append(positions[index])
		_receive_enemy_snapshot.rpc(batch_ids, batch_positions)
		offset = end

func _sync_boss_status() -> void:
	var boss: BaseEnemy = _enemies.get(_boss_net_id) as BaseEnemy
	boss_active = is_instance_valid(boss) and boss.alive
	boss_health_ratio = boss.health / boss.max_health if boss_active else 0.0
	_receive_boss_status.rpc(boss_active, boss_health_ratio)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_boss_status(active: bool, health_ratio: float) -> void:
	if multiplayer.is_server():
		return
	boss_active = active
	boss_health_ratio = clampf(health_ratio, 0.0, 1.0)

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_enemy_snapshot(ids: PackedInt32Array, positions: PackedVector2Array) -> void:
	if multiplayer.is_server() or ids.size() != positions.size():
		return
	var received_at: float = float(Time.get_ticks_msec()) / 1000.0
	for index: int in range(ids.size()):
		var net_id: int = ids[index]
		var enemy: BaseEnemy = _enemies.get(net_id) as BaseEnemy
		if is_instance_valid(enemy):
			enemy.replicated_position = positions[index]
			var history: Array = _snapshot_history.get(net_id, [])
			history.append({"time": received_at, "position": positions[index]})
			while history.size() > 2:
				history.pop_front()
			_snapshot_history[net_id] = history
