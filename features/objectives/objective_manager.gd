extends Node
class_name ObjectiveManager

signal chest_choice_requested(peer_id: int, chest_id: int, choices: PackedInt32Array)
signal chest_choice_closed(chest_id: int)

const CHEST_SCENE: PackedScene = preload("res://features/objectives/loot_chest.tscn")
const ACCESS_CARD_SCENE: PackedScene = preload("res://features/objectives/access_card.tscn")
const PILLAR_SCRIPT: Script = preload("res://features/objectives/battle_pillar.gd")
const PILLAR_POSITIONS: Array[Vector2] = [Vector2(-310.0, -180.0), Vector2(310.0, -180.0), Vector2(0.0, 340.0)]
const CHEST_INTERACT_RADIUS: float = 74.0
const CARD_PICKUP_RADIUS: float = 48.0
const CHEST_OFFSET: float = 132.0
const PILLAR_INTERACT_RADIUS: float = 100.0
const PILLAR_DEFEND_SECONDS: float = 8.0
const MAP_EVENT_SCRIPT: Script = preload("res://features/objectives/map_event_visual.gd")
const ANIMATED_EFFECT_SCRIPT: Script = preload("res://features/visuals/animated_strip_effect.gd")
const FIRST_EVENT_TIME: float = 75.0
const EVENT_REPEAT_SECONDS: float = 105.0
const EVENT_DURATION: float = 75.0
const EVENT_INTERACT_RADIUS: float = 112.0
const EVENT_ESCORT_RADIUS: float = 126.0

@onready var _chest_spawner: MultiplayerSpawner = $ChestSpawner
@onready var _access_card_spawner: MultiplayerSpawner = $AccessCardSpawner

var _next_chest_id: int = 1
var _next_card_id: int = 1
var team_access_cards: int = 0
var _chests: Dictionary = {}
var _access_cards: Dictionary = {}
var _pending_chest_choices: Dictionary = {}
var _pillars: Array[BattlePillar] = []
var _pillar_progress: Array[float] = []
var _pillar_buff_left: Array[float] = []
var _pillar_cooldown_left: Array[float] = []
var _sync_credit: float = 0.0
var active_event_kind: int = -1
var active_event_time_left: float = 0.0
var active_event_progress: float = 0.0
var active_event_health: float = 120.0
var active_event_position: Vector2 = Vector2.ZERO
var _event_route_start: Vector2 = Vector2.ZERO
var _event_route_midpoint: Vector2 = Vector2.ZERO
var _event_route_end: Vector2 = Vector2.ZERO
var event_result_text: String = ""
var event_result_left: float = 0.0
var bonus_gold: int = 0
var _next_event_time: float = FIRST_EVENT_TIME
var _event_interaction_cooldowns: Dictionary = {}
var _event_request_rate_limits: Dictionary = {}
var _event_visual: MapEventVisual

func _ready() -> void:
	_chest_spawner.spawn_path = NodePath("../../Actors")
	_chest_spawner.spawn_function = _make_chest
	_chest_spawner.despawned.connect(_on_chest_despawned)
	_access_card_spawner.spawn_path = NodePath("../../Actors")
	_access_card_spawner.spawn_function = _make_access_card
	_access_card_spawner.despawned.connect(_on_access_card_despawned)
	_build_pillars()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_process_map_event(delta)
	_process_access_cards()
	_process_chests()
	_sync_credit += delta
	for index: int in range(_pillars.size()):
		_pillar_cooldown_left[index] = maxf(0.0, _pillar_cooldown_left[index] - delta)
		_pillar_buff_left[index] = maxf(0.0, _pillar_buff_left[index] - delta)
		if _pillar_cooldown_left[index] > 0.0:
			_pillar_progress[index] = 0.0
			continue
		var position: Vector2 = _pillars[index].global_position
		var defenders: int = _living_players_near(position, PILLAR_INTERACT_RADIUS)
		var contested: bool = _enemy_near(position, PILLAR_INTERACT_RADIUS)
		if defenders > 0 and not contested:
			_pillar_progress[index] += delta * (1.0 + 0.25 * float(defenders - 1))
		else:
			_pillar_progress[index] = maxf(0.0, _pillar_progress[index] - delta * 0.5)
		if _pillar_progress[index] >= PILLAR_DEFEND_SECONDS:
			_activate_pillar(index)
	if _sync_credit >= 0.1:
		_sync_credit = fmod(_sync_credit, 0.1)
		for pillar_index: int in range(_pillars.size()):
			_replicate_pillar_state.rpc(pillar_index, _pillar_progress[pillar_index] / PILLAR_DEFEND_SECONDS, _pillar_buff_left[pillar_index], posmod(pillar_index, 3))

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		event_result_left = maxf(0.0, event_result_left - delta)
		if event_result_left <= 0.0:
			event_result_text = ""

func spawn_access_card(position: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var card_id: int = _next_card_id
	_next_card_id += 1
	_access_card_spawner.spawn({"card_id": card_id, "position": position})

func get_pillar_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for pillar: BattlePillar in _pillars:
		if is_instance_valid(pillar):
			result.append(pillar.global_position)
	return result

func request_event_interaction(peer_id: int) -> void:
	if multiplayer.is_server():
		_process_event_interaction(peer_id)
	else:
		_request_event_interaction.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _request_event_interaction() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var now: int = Time.get_ticks_msec()
	if now < int(_event_request_rate_limits.get(sender_id, 0)):
		return
	_event_request_rate_limits[sender_id] = now + 160
	_process_event_interaction(sender_id)

func _process_event_interaction(peer_id: int) -> void:
	if not multiplayer.is_server() or active_event_kind != 0:
		return
	var player: Player = _player_for_peer(peer_id)
	if player == null or player.replicated_downed or player.replicated_dead or player.replicated_health <= 0.0:
		return
	if player.global_position.distance_squared_to(active_event_position) > EVENT_INTERACT_RADIUS * EVENT_INTERACT_RADIUS:
		return
	var now: int = Time.get_ticks_msec()
	if now < int(_event_interaction_cooldowns.get(peer_id, 0)):
		return
	_event_interaction_cooldowns[peer_id] = now + 180
	active_event_health = maxf(0.0, active_event_health - 16.0 * (1.0 + player.replicated_weapon_damage / 80.0))
	if active_event_health <= 0.0:
		_complete_map_event(true)

func _process_map_event(delta: float) -> void:
	var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
	if world == null or world.game_over:
		return
	event_result_left = maxf(0.0, event_result_left - delta)
	if active_event_kind < 0:
		if world.elapsed_seconds >= _next_event_time and not world.is_boss_active():
			_begin_map_event()
		return
	active_event_time_left = maxf(0.0, active_event_time_left - delta)
	if active_event_kind == 1:
		var defenders: int = _living_players_near(active_event_position, EVENT_ESCORT_RADIUS)
		var contested: bool = _enemy_near(active_event_position, EVENT_ESCORT_RADIUS + 36.0)
		if defenders > 0 and not contested:
			active_event_progress = minf(24.0, active_event_progress + delta * minf(1.0 + float(defenders - 1) * 0.3, 1.9))
		else:
			active_event_progress = maxf(0.0, active_event_progress - delta * 0.25)
		active_event_position = _escort_position_at(active_event_progress / 24.0)
		if active_event_progress >= 24.0:
			_complete_map_event(true)
	if active_event_time_left <= 0.0:
		_complete_map_event(false)
	_sync_credit += delta
	if _sync_credit >= 0.12 and active_event_kind >= 0:
		_sync_credit = fmod(_sync_credit, 0.12)
		_replicate_map_event_state.rpc(active_event_kind, active_event_time_left, active_event_progress, active_event_health, active_event_position)

func _begin_map_event() -> void:
	var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
	if world == null:
		return
	active_event_kind = randi_range(0, 1)
	active_event_time_left = EVENT_DURATION
	active_event_progress = 0.0
	active_event_health = 120.0
	var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	var route_distance: float = minf(460.0, world.arena_radius * 0.42)
	_event_route_start = direction * route_distance
	_event_route_end = -direction * route_distance
	_event_route_midpoint = direction.rotated(PI * 0.5) * randf_range(-160.0, 160.0)
	active_event_position = _event_route_start if active_event_kind == 1 else direction * minf(520.0, world.arena_radius * 0.52)
	_event_interaction_cooldowns.clear()
	event_result_text = ""
	_next_event_time += EVENT_REPEAT_SECONDS
	_set_map_event.rpc(active_event_kind, active_event_position)
	_replicate_map_event_state.rpc(active_event_kind, active_event_time_left, active_event_progress, active_event_health, active_event_position)

func _complete_map_event(success: bool) -> void:
	if not multiplayer.is_server() or active_event_kind < 0:
		return
	var completed_kind: int = active_event_kind
	active_event_kind = -1
	active_event_time_left = 0.0
	active_event_progress = 0.0
	if success:
		bonus_gold += 220
		team_access_cards += 1
		_replicate_access_card_count.rpc(team_access_cards)
		var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
		if world != null:
			world.grant_team_xp(120)
			_spawn_chest(active_event_position + Vector2(72.0, 0.0), true)
		event_result_text = "NÚCLEO PURGADO · SUMINISTROS +220" if completed_kind == 0 else "DRON ESCOLTADO · SUMINISTROS +220"
	else:
		var spawner: EnemySpawner = get_parent().get_node_or_null("EnemySpawner") as EnemySpawner
		if spawner != null:
			spawner.apply_horde_enrage(35.0)
		event_result_text = "NÚCLEO SOBRECARGADO · HORDA ENFURECIDA" if completed_kind == 0 else "DRON PERDIDO · HORDA ENFURECIDA"
	event_result_left = 5.0
	_event_interaction_cooldowns.clear()
	_close_map_event.rpc(event_result_text)

func _player_for_peer(peer_id: int) -> Player:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.peer_id == peer_id:
			return player
	return null

func get_event_kind_name() -> String:
	if active_event_kind == 0:
		return "PURGA EL NÚCLEO CORRUPTO · F PARA ACTIVAR"
	if active_event_kind == 1:
		return "ESCOLTA EL DRON DE EXTRACCIÓN · SIGUE Y DEFIENDE"
	return event_result_text

func _escort_position_at(progress_ratio: float) -> Vector2:
	var t: float = clampf(progress_ratio, 0.0, 1.0)
	if t <= 0.5:
		return _event_route_start.lerp(_event_route_midpoint, t * 2.0)
	return _event_route_midpoint.lerp(_event_route_end, (t - 0.5) * 2.0)

func get_event_position() -> Vector2:
	return active_event_position

@rpc("authority", "call_local", "reliable")
func _set_map_event(kind: int, position: Vector2) -> void:
	if not is_instance_valid(_event_visual):
		var visual_node: Node2D = Node2D.new()
		visual_node.name = "MapEventVisual"
		visual_node.set_script(MAP_EVENT_SCRIPT)
		get_parent().get_node("Actors").add_child(visual_node)
		_event_visual = visual_node as MapEventVisual
	_event_visual.position = position
	_event_visual.event_kind = kind
	_event_visual.time_left = EVENT_DURATION
	_event_visual.progress = 0.0
	_event_visual.health = 120.0

@rpc("authority", "call_local", "unreliable")
func _replicate_map_event_state(kind: int, time_left: float, progress: float, health: float, position: Vector2) -> void:
	active_event_kind = kind
	active_event_time_left = maxf(0.0, time_left)
	active_event_progress = maxf(0.0, progress)
	active_event_health = maxf(0.0, health)
	active_event_position = position
	if is_instance_valid(_event_visual):
		_event_visual.position = position
		_event_visual.time_left = active_event_time_left
		_event_visual.progress = active_event_progress
		_event_visual.health = active_event_health
		_event_visual.queue_redraw()

@rpc("authority", "call_local", "reliable")
func _close_map_event(result_text: String) -> void:
	active_event_kind = -1
	active_event_time_left = 0.0
	event_result_text = result_text
	event_result_left = 5.0
	if is_instance_valid(_event_visual):
		_event_visual.queue_free()
		_event_visual = null

func _make_access_card(data: Variant) -> Node:
	var payload: Dictionary = data as Dictionary
	var card: AccessCardDrop = ACCESS_CARD_SCENE.instantiate() as AccessCardDrop
	card.card_id = int(payload["card_id"])
	card.position = payload["position"]
	_access_cards[card.card_id] = card
	return card

func _on_access_card_despawned(node: Node) -> void:
	var card: AccessCardDrop = node as AccessCardDrop
	if card != null:
		_access_cards.erase(card.card_id)

func _process_access_cards() -> void:
	for card_id_value: Variant in _access_cards.keys():
		var card_id: int = int(card_id_value)
		var card: AccessCardDrop = _access_cards.get(card_id) as AccessCardDrop
		if not is_instance_valid(card):
			continue
		var collector: Player
		for node: Node in get_tree().get_nodes_in_group("players"):
			var player: Player = node as Player
			if player == null or player.replicated_downed or player.replicated_dead or player.replicated_health <= 0.0:
				continue
			if player.global_position.distance_squared_to(card.global_position) <= CARD_PICKUP_RADIUS * CARD_PICKUP_RADIUS:
				collector = player
				break
		if collector == null:
			continue
		var drop_position: Vector2 = card.global_position
		_access_cards.erase(card_id)
		card.queue_free()
		team_access_cards += 1
		_replicate_access_card_count.rpc(team_access_cards)
		var direction: Vector2 = Vector2.RIGHT.rotated(randf_range(0.0, TAU))
		_spawn_chest(drop_position + direction * CHEST_OFFSET)

func _spawn_chest(position: Vector2, golden: bool = false) -> void:
	var chest_id: int = _next_chest_id
	_next_chest_id += 1
	var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
	var safe_position: Vector2 = position
	if world != null and safe_position.length() > world.arena_radius - 120.0:
		safe_position = safe_position.normalized() * (world.arena_radius - 120.0)
	_chest_spawner.spawn({"chest_id": chest_id, "position": safe_position, "golden": golden})

func is_golden_chest(chest_id: int) -> bool:
	var chest: LootChest = _chests.get(chest_id) as LootChest
	return is_instance_valid(chest) and chest.is_golden

func choose_chest(chest_id: int, choice: int) -> void:
	if multiplayer.is_server():
		_process_chest_choice(multiplayer.get_unique_id(), chest_id, choice)
	else:
		_request_chest_choice.rpc_id(1, chest_id, choice)

func _make_chest(data: Variant) -> Node:
	var payload: Dictionary = data as Dictionary
	var chest: LootChest = CHEST_SCENE.instantiate() as LootChest
	chest.chest_id = int(payload["chest_id"])
	chest.position = payload["position"]
	chest.is_golden = bool(payload.get("golden", false))
	chest.queue_redraw()
	_chests[chest.chest_id] = chest
	return chest

func _on_chest_despawned(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var chest: LootChest = node as LootChest
	if chest != null:
		_chests.erase(chest.chest_id)
		if _pending_chest_choices.has(chest.chest_id):
			var pending: Dictionary = _pending_chest_choices[chest.chest_id]
			_pending_chest_choices.erase(chest.chest_id)
			if multiplayer.is_server():
				_refund_reserved_access_card(pending)

func _process_chests() -> void:
	for raw_id: Variant in _chests.keys():
		var chest_id: int = int(raw_id)
		if _pending_chest_choices.has(chest_id):
			var pending_choice: Dictionary = _pending_chest_choices[chest_id]
			if Time.get_ticks_msec() < int(pending_choice.get("expires_at", 0)):
				continue
			_pending_chest_choices.erase(chest_id)
			_refund_reserved_access_card(pending_choice)
			_cancel_chest_offer.rpc(int(pending_choice.get("peer_id", -1)), chest_id)
		var chest_value: Variant = _chests.get(chest_id)
		if not is_instance_valid(chest_value):
			_chests.erase(chest_id)
			continue
		if team_access_cards <= 0:
			continue
		var chest: LootChest = chest_value as LootChest
		if chest == null:
			_chests.erase(chest_id)
			continue
		var closest: Player
		var nearest_distance: float = CHEST_INTERACT_RADIUS * CHEST_INTERACT_RADIUS
		for node: Node in get_tree().get_nodes_in_group("players"):
			var player: Player = node as Player
			if player == null or player.replicated_health <= 0.0 or player.replicated_downed or player.replicated_dead:
				continue
			var distance: float = player.global_position.distance_squared_to(chest.global_position)
			if distance <= nearest_distance:
				closest = player
				nearest_distance = distance
		if closest == null:
			continue
		var options: Array[int] = [0, 1, 2, 3, 4]
		for item_id: int in range(EquipmentCatalog.FIRST_EQUIPMENT_ID, EquipmentCatalog.FIRST_EQUIPMENT_ID + EquipmentCatalog.ITEMS.size()):
			var item_index: int = item_id - EquipmentCatalog.FIRST_EQUIPMENT_ID
			if closest.get_equipment_stacks(item_index) < EquipmentCatalog.MAX_STACKS:
				options.append(item_id)
		options.shuffle()
		var packed_options: PackedInt32Array = PackedInt32Array([options[0], options[1], options[2]])
		team_access_cards -= 1
		_replicate_access_card_count.rpc(team_access_cards)
		_pending_chest_choices[chest_id] = {"peer_id": closest.peer_id, "choices": packed_options, "expires_at": Time.get_ticks_msec() + 30000, "reserved_card": true}
		_offer_chest_choice.rpc(closest.peer_id, chest_id, packed_options)

@rpc("any_peer", "call_remote", "reliable")
func _request_chest_choice(chest_id: int, choice: int) -> void:
	if not multiplayer.is_server():
		return
	_process_chest_choice(multiplayer.get_remote_sender_id(), chest_id, choice)

func _process_chest_choice(sender_id: int, chest_id: int, choice: int) -> void:
	if not multiplayer.is_server() or not _pending_chest_choices.has(chest_id):
		return
	var pending: Dictionary = _pending_chest_choices[chest_id]
	var options: PackedInt32Array = pending["choices"]
	if Time.get_ticks_msec() >= int(pending.get("expires_at", 0)) or sender_id != int(pending["peer_id"]) or not options.has(choice):
		return
	var chest: LootChest = _chests.get(chest_id) as LootChest
	var chooser: Player
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.peer_id == sender_id:
			chooser = player
			break
	if not is_instance_valid(chest) or not is_instance_valid(chooser):
		_pending_chest_choices.erase(chest_id)
		_refund_reserved_access_card(pending)
		_cancel_chest_offer.rpc(sender_id, chest_id)
		return
	if chooser.replicated_downed or chooser.replicated_dead or chooser.global_position.distance_squared_to(chest.global_position) > CHEST_INTERACT_RADIUS * CHEST_INTERACT_RADIUS:
		_pending_chest_choices.erase(chest_id)
		_refund_reserved_access_card(pending)
		_cancel_chest_offer.rpc(sender_id, chest_id)
		return
	chooser.apply_chest_upgrade(choice)
	_close_chest.rpc(chest_id)

func _refund_reserved_access_card(pending: Dictionary) -> void:
	if not bool(pending.get("reserved_card", false)):
		return
	team_access_cards += 1
	_replicate_access_card_count.rpc(team_access_cards)

@rpc("authority", "call_local", "reliable")
func _replicate_access_card_count(count: int) -> void:
	team_access_cards = maxi(0, count)

@rpc("authority", "call_local", "reliable")
func _offer_chest_choice(peer_id: int, chest_id: int, choices: PackedInt32Array) -> void:
	chest_choice_requested.emit(peer_id, chest_id, choices)

@rpc("authority", "call_local", "reliable")
func _close_chest(chest_id: int) -> void:
	_pending_chest_choices.erase(chest_id)
	var chest: LootChest = _chests.get(chest_id) as LootChest
	_chests.erase(chest_id)
	if is_instance_valid(chest):
		_replicate_chest_effect.rpc(chest.global_position, chest.is_golden)
	if multiplayer.is_server() and is_instance_valid(chest):
		chest.queue_free()
	chest_choice_closed.emit(chest_id)

@rpc("authority", "call_local", "unreliable")
func _replicate_chest_effect(effect_position: Vector2, golden: bool) -> void:
	if NetworkManager.is_dedicated_mode():
		return
	var effect: Node2D = Node2D.new()
	effect.set_script(ANIMATED_EFFECT_SCRIPT)
	effect.set("texture_path", "res://art/external/combat_fx/chest_burst_32x32_6f.png")
	effect.set("frame_size", 32)
	effect.set("frame_count", 6)
	effect.set("effect_scale", 2.8 if golden else 2.2)
	effect.set("tint", Color("#ffe5a3") if golden else Color.WHITE)
	effect.global_position = effect_position
	get_parent().get_node("Actors").add_child(effect)

@rpc("authority", "call_local", "reliable")
func _cancel_chest_offer(peer_id: int, chest_id: int) -> void:
	if peer_id < 0:
		return
	chest_choice_closed.emit(chest_id)

func _build_pillars() -> void:
	var actors: Node2D = get_parent().get_node("Actors") as Node2D
	for index: int in range(PILLAR_POSITIONS.size()):
		var pillar_node: Node2D = Node2D.new()
		pillar_node.set_script(PILLAR_SCRIPT)
		var pillar: BattlePillar = pillar_node as BattlePillar
		pillar.pillar_id = index
		pillar.position = PILLAR_POSITIONS[index]
		actors.add_child(pillar)
		_pillars.append(pillar)
		_pillar_progress.append(0.0)
		_pillar_buff_left.append(0.0)
		_pillar_cooldown_left.append(0.0)

func _activate_pillar(index: int) -> void:
	_pillar_progress[index] = 0.0
	_pillar_buff_left[index] = 22.0
	_pillar_cooldown_left[index] = 55.0
	var buff_kind: int = posmod(index, 3)
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.replicated_health > 0.0 and not player.replicated_downed and not player.replicated_dead:
			player.apply_pillar_buff(buff_kind, 22.0)
	_replicate_pillar_state.rpc(index, 0.0, 22.0, buff_kind)

@rpc("authority", "call_local", "unreliable")
func _replicate_pillar_state(index: int, progress: float, buff_left: float, kind: int) -> void:
	if index < 0 or index >= _pillars.size():
		return
	_pillars[index].progress = clampf(progress, 0.0, 1.0)
	_pillars[index].buff_seconds = maxf(0.0, buff_left)
	_pillars[index].buff_kind = posmod(kind, 3)

func _living_players_near(position: Vector2, radius: float) -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.replicated_health > 0.0 and not player.replicated_downed and not player.replicated_dead and player.global_position.distance_squared_to(position) <= radius * radius:
			count += 1
	return count

func _enemy_near(position: Vector2, radius: float) -> bool:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy != null and enemy.alive and enemy.global_position.distance_squared_to(position) <= radius * radius:
			return true
	return false

