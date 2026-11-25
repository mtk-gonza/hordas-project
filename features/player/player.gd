extends CharacterBody2D
class_name Player

@export var peer_id: int = 1
@export var initial_health: float = 100.0
@export var character_id: StringName = &"warden"

var replicated_position: Vector2 = Vector2.ZERO
var replicated_move_speed: float = 245.0
var replicated_weapon_damage: float = 16.0
var replicated_attack_range: float = 118.0
var replicated_attack_cooldown: float = 1.05
var replicated_input_ack: int = 0
var replicated_facing: Vector2 = Vector2.RIGHT
var replicated_animation: StringName = &"idle"
var replicated_downed: bool = false
var replicated_dead: bool = false
var replicated_player_paused: bool = false
var replicated_bleedout_left: float = 0.0
var replicated_revive_progress: float = 0.0
var replicated_reviver_peer_id: int = -1
var replicated_respawn_at: float = -1.0
var replicated_ultimate_cooldown_left: float = 0.0
var replicated_skill_cooldown_left: float = 0.0
var replicated_ultimate_duration_bonus: float = 0.0
var replicated_weapon_level: int = 1
var replicated_attack_speed_passive: bool = false
var replicated_weapon_evolved: bool = false
var replicated_dart_level: int = 0
var replicated_dart_evolved: bool = false
var replicated_blade_level: int = 0
var replicated_blade_evolved: bool = false
var replicated_personal_damage_bonus: float = 0.0
var replicated_lifesteal: float = 0.0
var replicated_kill_burst_level: int = 0
var replicated_ultimate_damage_bonus: float = 0.0
var replicated_pulse_echo_level: int = 0
var replicated_kill_momentum_level: int = 0
var replicated_upgrade_choices: PackedInt32Array = PackedInt32Array()
var replicated_passive_move_bonus: float = 0.0
var replicated_team_damage_bonus: float = 0.0
var replicated_team_speed_bonus: float = 0.0
var replicated_team_buff_left: float = 0.0
var replicated_equipment_levels: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
var replicated_damage_reduction: float = 0.0
var replicated_ultimate_cooldown_reduction: float = 0.0
var replicated_pulse_cooldown_left: float = 0.0
var replicated_dart_cooldown_left: float = 0.0
var replicated_blade_cooldown_left: float = 0.0

const BLEEDOUT_SECONDS: float = 25.0
const REVIVE_SECONDS: float = 5.0
const REVIVE_RADIUS: float = 62.0
const REVIVE_HEALTH_RATIO: float = 0.35
const ULTIMATE_BURST_SCRIPT: Script = preload("res://features/player/ultimate_burst.gd")
const CHARACTER_SKILL_BURST_SCRIPT: Script = preload("res://features/player/character_skill_burst.gd")
const ANIMATED_EFFECT_SCRIPT: Script = preload("res://features/visuals/animated_strip_effect.gd")
const PASSIVE_SCRIPTS: Dictionary = {
	&"warden": preload("res://features/player/passives/warden_passive.gd"),
	&"stormcaller": preload("res://features/player/passives/stormcaller_passive.gd"),
	&"moonkeeper": preload("res://features/player/passives/moonkeeper_passive.gd"),
	&"grovekeeper": preload("res://features/player/passives/grovekeeper_passive.gd")
}
var _ultimate_definition: UltimateDefinition
var _reviver_count: int = 0
var _ultimate_active_left: float = 0.0
var _ultimate_tick_left: float = 0.0
var _ultimate_tick_damage: float = 0.0
var _ultimate_active_radius: float = 0.0

var replicated_health: float:
	get:
		return _health.current_health if is_instance_valid(_health) else initial_health
	set(value):
		if is_instance_valid(_health):
			_health.set_replicated_health(value)

var replicated_max_health: float:
	get:
		return _health.maximum_health if is_instance_valid(_health) else initial_health
	set(value):
		if is_instance_valid(_health):
			_health.set_replicated_maximum(value)

var replicated_xp: int:
	get:
		return _progression.current_xp if is_instance_valid(_progression) else 0
	set(value):
		if is_instance_valid(_progression):
			_progression.set_replicated_xp(value)

var replicated_level: int:
	get:
		return _progression.current_level if is_instance_valid(_progression) else 1
	set(value):
		if is_instance_valid(_progression):
			_progression.set_replicated_level(value)

var replicated_xp_to_next: int:
	get:
		return _progression.xp_to_next if is_instance_valid(_progression) else 100
	set(value):
		if is_instance_valid(_progression):
			_progression.set_replicated_xp_to_next(value)

var replicated_upgrade_tokens: int:
	get:
		return _progression.upgrade_tokens if is_instance_valid(_progression) else 0
	set(value):
		if is_instance_valid(_progression):
			_progression.set_replicated_upgrade_tokens(value)

var _server_input: Vector2 = Vector2.ZERO
var _input_sequence: int = 0
var _last_server_input_sequence: int = 0
var _last_reconciled_sequence: int = 0
var _input_window_started_msec: int = 0
var _input_requests_this_window: int = 0
var _pending_inputs: Array[Dictionary] = []
var _attack_animation_left: float = 0.0
var _damage_invulnerability_left: float = 0.0
var _attack_target: BaseEnemy
var _dead: bool = false
var _dart_cooldown_left: float = 0.0
var _blade_tick_left: float = 0.0
var _passive_momentum_left: float = 0.0
var _pulse_echo_progress: int = 0
var _kill_explosion_active: bool = false

signal on_enemy_killed(enemy: BaseEnemy, world_position: Vector2)
signal on_weapon_fired(weapon_id: StringName, hit_count: int)

@onready var _visual: PlayerVisual = $Visual
@onready var _camera: Camera2D = $Camera2D
@onready var _pulse: Area2D = $WeaponMount/CircularPulse
@onready var _synchronizer: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var _health: HealthComponent = $Health
@onready var _progression: ExperienceComponent = $Progression

func _ready() -> void:
	add_to_group("players")
	_health.initialize(initial_health)
	_progression.initialize()
	replicated_position = global_position
	set_multiplayer_authority(1, true)
	_configure_synchronizer()
	_camera.enabled = false
	_ultimate_definition = UltimateCatalog.for_character(character_id)
	var passive_node: Node = Node.new()
	passive_node.name = "CharacterPassive"
	passive_node.set_script(PASSIVE_SCRIPTS.get(character_id, PASSIVE_SCRIPTS[&"warden"]) as Script)
	add_child(passive_node)
	_visual.set_player_style(peer_id)
	_visual.set_animation_state(replicated_animation, replicated_facing)
	_visual.set_downed(replicated_downed, replicated_revive_progress)

func _physics_process(delta: float) -> void:
	if replicated_dead:
		_dead = true
		replicated_animation = &"death"
		_visual.set_downed(false, 0.0)
		_visual.set_animation_state(replicated_animation, replicated_facing)
		return
	if multiplayer.is_server() and replicated_health <= 0.0 and not replicated_downed:
		_enter_downed()
	if replicated_downed:
		if multiplayer.is_server():
			_tick_downed(delta)
		_visual.set_downed(replicated_downed, replicated_revive_progress)
		return
	var world: Node = get_tree().get_first_node_in_group("session_world")
	if world != null and bool(world.get("game_over")):
		velocity = Vector2.ZERO
		replicated_animation = &"idle"
		_visual.set_animation_state(replicated_animation, replicated_facing)
		return
	var is_server: bool = multiplayer.is_server()
	var is_owner: bool = multiplayer.get_unique_id() == peer_id
	if is_server:
		_attack_animation_left = maxf(0.0, _attack_animation_left - delta)
		_damage_invulnerability_left = maxf(0.0, _damage_invulnerability_left - delta)
		replicated_ultimate_cooldown_left = maxf(0.0, replicated_ultimate_cooldown_left - delta)
		replicated_skill_cooldown_left = maxf(0.0, replicated_skill_cooldown_left - delta)
		_passive_momentum_left = maxf(0.0, _passive_momentum_left - delta)
		if _passive_momentum_left <= 0.0:
			replicated_passive_move_bonus = 0.0
		if not replicated_player_paused:
			_tick_ultimate(delta)
		if replicated_team_buff_left > 0.0:
			replicated_team_buff_left = maxf(0.0, replicated_team_buff_left - delta)
			if replicated_team_buff_left <= 0.0:
				replicated_team_damage_bonus = 0.0
				replicated_team_speed_bonus = 0.0
		if peer_id == 1:
			_server_input = _read_move_input() if not replicated_player_paused else Vector2.ZERO
			if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("interact"):
				_request_map_event_interaction()
			if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("attack"):
				_pulse.call("try_fire")
			if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("ultimate"):
				_activate_ultimate()
			if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("character_skill"):
				_activate_character_skill()
		_server_move(_server_input)
		replicated_position = global_position
		_update_auto_target()
		_tick_secondary_weapons(delta)
		_update_animation()
	elif is_owner:
		_reconcile_predicted_state()
		var movement: Vector2 = _read_move_input()
		_input_sequence += 1
		_pending_inputs.append({"sequence": _input_sequence, "movement": movement, "delta": delta})
		if _pending_inputs.size() > 120:
			_pending_inputs.pop_front()
		_submit_input.rpc_id(1, _input_sequence, movement)
		_predict_local_move(movement, delta)
		_update_local_facing(movement)
		_update_animation()
		if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("attack"):
			_request_manual_attack.rpc_id(1)
		if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("ultimate"):
			_request_ultimate.rpc_id(1)
		if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("character_skill"):
			_request_character_skill.rpc_id(1)
		if not replicated_player_paused and not NetworkManager.is_local_game_paused() and Input.is_action_just_pressed("interact"):
			_request_map_event_interaction()
	else:
		global_position = global_position.lerp(replicated_position, 1.0 - exp(-delta * 14.0))
		_visual.set_animation_state(replicated_animation, replicated_facing)

func _read_move_input() -> Vector2:
	if NetworkManager.is_local_game_paused():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").limit_length(1.0)

func _request_map_event_interaction() -> void:
	var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
	if world != null and is_instance_valid(world.objective_manager):
		world.objective_manager.request_event_interaction(peer_id)

func _server_move(movement: Vector2) -> void:
	velocity = movement.limit_length(1.0) * replicated_move_speed * (1.0 + replicated_team_speed_bonus + replicated_passive_move_bonus)
	move_and_slide()
	if multiplayer.is_server() and velocity.length_squared() > 1.0:
		replicated_facing = velocity.normalized()
	_constrain_to_arena()
	if multiplayer.is_server():
		replicated_position = global_position

func _predict_local_move(movement: Vector2, delta: float) -> void:
	global_position += movement.limit_length(1.0) * replicated_move_speed * (1.0 + replicated_team_speed_bonus + replicated_passive_move_bonus) * delta
	_constrain_to_arena()
	velocity = movement.limit_length(1.0) * replicated_move_speed

func _reconcile_predicted_state() -> void:
	if replicated_input_ack <= _last_reconciled_sequence:
		return
	_last_reconciled_sequence = replicated_input_ack
	while not _pending_inputs.is_empty() and int(_pending_inputs[0]["sequence"]) <= replicated_input_ack:
		_pending_inputs.pop_front()
	global_position = replicated_position
	for input_state: Dictionary in _pending_inputs:
		var movement: Vector2 = input_state["movement"]
		var input_delta: float = float(input_state["delta"])
		global_position += movement * replicated_move_speed * input_delta
		_constrain_to_arena()

func _constrain_to_arena() -> void:
	var world: Node = get_tree().get_first_node_in_group("session_world")
	if world != null:
		var offset: Vector2 = global_position
		var arena_radius: float = float(world.get("arena_radius"))
		if offset.length() > arena_radius - 24.0:
			global_position = offset.normalized() * (arena_radius - 24.0)
		if multiplayer.is_server():
			global_position = world.call("constrain_to_battle_circle", self, global_position)

@rpc("any_peer", "call_local", "unreliable_ordered")
func _submit_input(sequence: int, movement: Vector2) -> void:
	if not multiplayer.is_server() or _dead:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != peer_id or sequence <= _last_server_input_sequence or sequence - _last_server_input_sequence > 120 or not is_finite(movement.x) or not is_finite(movement.y):
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _input_window_started_msec >= 1000:
		_input_window_started_msec = now_msec
		_input_requests_this_window = 0
	if _input_requests_this_window >= 90:
		return
	_input_requests_this_window += 1
	_last_server_input_sequence = sequence
	replicated_input_ack = sequence
	_server_input = Vector2.ZERO if replicated_player_paused else movement.limit_length(1.0)

@rpc("any_peer", "call_local", "reliable")
func _request_manual_attack() -> void:
	if not multiplayer.is_server() or _dead or replicated_player_paused:
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != peer_id:
		return
	_pulse.call("try_fire")

@rpc("any_peer", "call_remote", "reliable")
func _request_ultimate() -> void:
	if not multiplayer.is_server() or replicated_downed or replicated_dead or replicated_player_paused:
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_activate_ultimate()

@rpc("any_peer", "call_remote", "reliable")
func _request_character_skill() -> void:
	if not multiplayer.is_server() or replicated_downed or replicated_dead or replicated_player_paused:
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_activate_character_skill()

func _activate_character_skill() -> void:
	if not multiplayer.is_server() or replicated_downed or replicated_dead or replicated_player_paused or replicated_skill_cooldown_left > 0.0:
		return
	const radius: float = 245.0
	const cooldown: float = 10.0
	replicated_skill_cooldown_left = cooldown
	var damage: float = replicated_weapon_damage * 2.35 * (1.0 + replicated_personal_damage_bonus + replicated_team_damage_bonus)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy == null or not enemy.alive or global_position.distance_squared_to(enemy.global_position) > radius * radius:
			continue
		enemy.take_damage(damage, peer_id)
		var push_direction: Vector2 = enemy.global_position - global_position
		if push_direction.length_squared() > 0.01:
			enemy.global_position += push_direction.normalized() * (26.0 if enemy.is_boss else 54.0)
	_replicate_character_skill.rpc(radius, Color("#5fe6ed") if character_id == &"stormcaller" else Color("#ffb64e"))
	trigger_attack_animation()

@rpc("authority", "call_local", "reliable")
func _replicate_character_skill(radius: float, tint: Color) -> void:
	if NetworkManager.is_dedicated_mode():
		return
	var burst: Node2D = Node2D.new()
	burst.set_script(CHARACTER_SKILL_BURST_SCRIPT)
	burst.set("radius", radius)
	burst.set("tint", tint)
	add_child(burst)

func _activate_ultimate() -> void:
	if not multiplayer.is_server() or replicated_downed or replicated_dead or replicated_player_paused or replicated_ultimate_cooldown_left > 0.0:
		return
	if _ultimate_definition == null:
		_ultimate_definition = UltimateCatalog.for_character(character_id)
	replicated_ultimate_cooldown_left = get_ultimate_cooldown()
	_ultimate_active_left = _ultimate_definition.effect_duration * (1.0 + replicated_ultimate_duration_bonus)
	_ultimate_tick_left = 0.25
	_ultimate_tick_damage = _ultimate_definition.damage * (1.0 + replicated_personal_damage_bonus + replicated_team_damage_bonus + replicated_ultimate_damage_bonus) / 5.0
	_ultimate_active_radius = _ultimate_definition.radius
	_apply_ultimate_damage_tick()
	_replicate_ultimate.rpc(_ultimate_definition.radius, _ultimate_active_left, _ultimate_definition.effect_color)
	trigger_attack_animation()

func _tick_ultimate(delta: float) -> void:
	if _ultimate_active_left <= 0.0:
		return
	_ultimate_active_left = maxf(0.0, _ultimate_active_left - delta)
	_ultimate_tick_left -= delta
	if _ultimate_tick_left <= 0.0 and _ultimate_active_left > 0.0:
		_ultimate_tick_left = 0.25
		_apply_ultimate_damage_tick()

func _apply_ultimate_damage_tick() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy == null or not enemy.alive:
			continue
		if global_position.distance_squared_to(enemy.global_position) <= _ultimate_active_radius * _ultimate_active_radius:
			enemy.take_damage(_ultimate_tick_damage, peer_id)
			var push: Vector2 = enemy.global_position - global_position
			if push.length_squared() > 0.01:
				enemy.global_position += push.normalized() * (12.0 if enemy.is_boss else 18.0)

@rpc("authority", "call_local", "reliable")
func _replicate_ultimate(radius: float, duration: float, tint: Color) -> void:
	if NetworkManager.is_dedicated_mode():
		return
	var burst: Node2D = Node2D.new()
	burst.set_script(ULTIMATE_BURST_SCRIPT)
	burst.set("radius", radius)
	burst.set("duration", duration)
	burst.set("tint", tint)
	match character_id:
		&"stormcaller":
			burst.set("texture_path", "res://art/external/combat_fx/lightning_ultimate_64x64_10f.png")
		&"moonkeeper":
			burst.set("texture_path", "res://art/external/combat_fx/shadow_ultimate_64x64_10f.png")
		&"grovekeeper":
			burst.set("texture_path", "res://art/external/combat_fx/holy_ultimate_64x64_10f.png")
	add_child(burst)

func _enter_downed() -> void:
	if replicated_downed or replicated_dead:
		return
	replicated_downed = true
	replicated_bleedout_left = BLEEDOUT_SECONDS
	replicated_revive_progress = 0.0
	replicated_reviver_peer_id = -1
	velocity = Vector2.ZERO
	_visual.set_downed(true, 0.0)

func _tick_downed(delta: float) -> void:
	replicated_bleedout_left = maxf(0.0, replicated_bleedout_left - delta)
	var candidates: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		var ally: Player = node as Player
		if ally == null or ally == self or ally.replicated_health <= 0.0 or ally.replicated_downed or ally.replicated_dead:
			continue
		if ally.global_position.distance_squared_to(global_position) <= REVIVE_RADIUS * REVIVE_RADIUS:
			candidates.append(ally)
	candidates.sort_custom(func(a: Player, b: Player) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)
	)
	var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
	var selected_reviver_id: int = -1
	if world != null:
		for ally: Player in candidates:
			if world.try_claim_revive(ally.peer_id, peer_id):
				selected_reviver_id = ally.peer_id
				break
	if selected_reviver_id >= 0:
		replicated_reviver_peer_id = selected_reviver_id
		replicated_revive_progress = minf(1.0, replicated_revive_progress + delta / REVIVE_SECONDS)
	else:
		if world != null:
			world.release_revive_claim_for_target(peer_id)
		replicated_reviver_peer_id = -1
		replicated_revive_progress = maxf(0.0, replicated_revive_progress - delta * 0.06)
	_visual.set_downed(true, replicated_revive_progress)
	if replicated_revive_progress >= 1.0:
		if world != null:
			world.release_revive_claim_for_target(peer_id)
		replicated_downed = false
		replicated_bleedout_left = 0.0
		replicated_health = replicated_max_health * REVIVE_HEALTH_RATIO
		replicated_reviver_peer_id = -1
		replicated_animation = &"idle"
		_visual.set_downed(false, 0.0)
	elif replicated_bleedout_left <= 0.0:
		if world != null:
			world.release_revive_claim_for_target(peer_id)
		replicated_dead = true
		replicated_downed = false
		replicated_reviver_peer_id = -1
		replicated_respawn_at = _get_next_wave_respawn_time()
		_dead = true
		replicated_animation = &"death"
		_visual.set_downed(false, 0.0)
		_visual.set_animation_state(replicated_animation, replicated_facing)

func _get_next_wave_respawn_time() -> float:
	var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
	if world == null or world.game_over or world.is_boss_active():
		return -1.0
	return (floorf(world.elapsed_seconds / 60.0) + 1.0) * 60.0

func can_respawn_at(elapsed_seconds: float) -> bool:
	return multiplayer.is_server() and replicated_dead and replicated_respawn_at >= 0.0 and elapsed_seconds >= replicated_respawn_at

func respawn_at_wave(spawn_position: Vector2) -> void:
	if not multiplayer.is_server() or not replicated_dead:
		return
	_replicate_wave_respawn.rpc(spawn_position, replicated_max_health * 0.5)

@rpc("authority", "call_local", "reliable")
func _replicate_wave_respawn(spawn_position: Vector2, health_value: float) -> void:
	global_position = spawn_position
	replicated_position = spawn_position
	replicated_health = health_value
	replicated_downed = false
	replicated_dead = false
	replicated_bleedout_left = 0.0
	replicated_revive_progress = 0.0
	replicated_reviver_peer_id = -1
	replicated_respawn_at = -1.0
	_server_input = Vector2.ZERO
	_dead = false
	_damage_invulnerability_left = 2.5
	replicated_animation = &"idle"
	_visual.set_downed(false, 0.0)
	_visual.set_animation_state(replicated_animation, replicated_facing)

func apply_chest_upgrade(choice: int) -> void:
	if not multiplayer.is_server() or replicated_dead or replicated_downed:
		return
	match choice:
		0:
			_apply_weapon_level()
		1:
			replicated_attack_speed_passive = true
			replicated_attack_cooldown = maxf(0.35, replicated_attack_cooldown * 0.82)
			_check_weapon_evolution()
		2:
			_health.increase_maximum(28.0, 28.0)
		3:
			replicated_weapon_damage *= 1.22
		4:
			replicated_ultimate_cooldown_left = maxf(0.0, replicated_ultimate_cooldown_left - 18.0)
		_:
			if EquipmentCatalog.is_equipment_choice(choice):
				equip_item(choice)
	_refresh_upgrade_choices()

func equip_item(choice_id: int) -> bool:
	if not multiplayer.is_server() or not EquipmentCatalog.is_equipment_choice(choice_id):
		return false
	var index: int = choice_id - EquipmentCatalog.FIRST_EQUIPMENT_ID
	if replicated_equipment_levels[index] >= EquipmentCatalog.MAX_STACKS:
		return false
	replicated_equipment_levels[index] += 1
	match choice_id:
		5:
			replicated_personal_damage_bonus += 0.12
		6:
			replicated_damage_reduction = minf(0.24, replicated_damage_reduction + 0.08)
			_health.increase_maximum(20.0, 20.0)
		7:
			replicated_move_speed *= 1.09
		8:
			replicated_personal_damage_bonus += 0.07
			replicated_attack_cooldown = maxf(0.3, replicated_attack_cooldown * 0.93)
		9:
			replicated_ultimate_cooldown_reduction = minf(0.24, replicated_ultimate_cooldown_reduction + 0.08)
	return true

func get_equipment_stacks(index: int) -> int:
	if index < 0 or index >= replicated_equipment_levels.size():
		return 0
	return replicated_equipment_levels[index]

func get_pulse_cooldown() -> float:
	return float(_pulse.get("base_cooldown")) if is_instance_valid(_pulse) else 1.0

func get_dart_cooldown() -> float:
	return maxf(0.42, 1.72 - float(maxi(0, replicated_dart_level - 1)) * 0.16 - float(replicated_attack_speed_passive) * 0.2)

func get_blade_cooldown() -> float:
	return maxf(0.32, 0.78 - float(maxi(0, replicated_blade_level - 1)) * 0.055)

func apply_pillar_buff(kind: int, duration: float) -> void:
	if not multiplayer.is_server():
		return
	replicated_team_buff_left = maxf(replicated_team_buff_left, duration)
	match posmod(kind, 3):
		0:
			replicated_team_damage_bonus = maxf(replicated_team_damage_bonus, 0.25)
		1:
			replicated_team_speed_bonus = maxf(replicated_team_speed_bonus, 0.22)
		2:
			_health.heal(replicated_max_health * 0.35)

func _apply_weapon_level() -> void:
	if replicated_weapon_level >= 5:
		return
	replicated_weapon_level += 1
	replicated_weapon_damage *= 1.12
	replicated_attack_range += 8.0
	_check_weapon_evolution()

func _check_weapon_evolution() -> void:
	if replicated_weapon_level >= 5 and replicated_attack_speed_passive and not replicated_weapon_evolved:
		replicated_weapon_evolved = true
		replicated_weapon_damage *= 1.55
		replicated_attack_range += 72.0
		replicated_attack_cooldown = maxf(0.3, replicated_attack_cooldown * 0.72)
	if replicated_dart_level >= 5 and replicated_attack_speed_passive:
		replicated_dart_evolved = true
	if replicated_blade_level >= 5 and replicated_personal_damage_bonus >= 0.36:
		replicated_blade_evolved = true

func _tick_secondary_weapons(delta: float) -> void:
	if not multiplayer.is_server() or replicated_downed or replicated_dead or replicated_player_paused:
		return
	_dart_cooldown_left = maxf(0.0, _dart_cooldown_left - delta)
	_blade_tick_left = maxf(0.0, _blade_tick_left - delta)
	replicated_dart_cooldown_left = _dart_cooldown_left
	replicated_blade_cooldown_left = _blade_tick_left
	if replicated_dart_level > 0 and _dart_cooldown_left <= 0.0:
		var dart_target_count: int = 1 + int(replicated_dart_level >= 3) + int(replicated_dart_evolved)
		var dart_targets: Array[BaseEnemy] = _nearest_enemies(620.0, dart_target_count)
		if not dart_targets.is_empty():
			_fire_dart_volley(dart_targets)
			_dart_cooldown_left = maxf(0.42, 1.72 - float(replicated_dart_level - 1) * 0.16 - float(replicated_attack_speed_passive) * 0.2)
	if replicated_blade_level > 0 and _blade_tick_left <= 0.0:
		_fire_orbiting_blades()
		_blade_tick_left = maxf(0.32, 0.78 - float(replicated_blade_level - 1) * 0.055)

func _nearest_enemies(maximum_distance: float, limit: int) -> Array[BaseEnemy]:
	var candidates: Array[BaseEnemy] = []
	var max_distance_squared: float = maximum_distance * maximum_distance
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy == null or not enemy.alive or enemy.global_position.distance_squared_to(global_position) > max_distance_squared:
			continue
		candidates.append(enemy)
	candidates.sort_custom(func(a: BaseEnemy, b: BaseEnemy) -> bool:
		return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position)
	)
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates

func _fire_dart_volley(targets: Array[BaseEnemy]) -> void:
	var dart_damage: float = replicated_weapon_damage * (0.72 + 0.12 * float(replicated_dart_level)) * (1.0 + replicated_personal_damage_bonus + replicated_team_damage_bonus)
	for target: BaseEnemy in targets:
		if not is_instance_valid(target) or not target.alive:
			continue
		target.take_damage(dart_damage, peer_id)
		_visual.replicate_weapon_trail.rpc(target.global_position, 0)
	trigger_attack_animation()
	notify_weapon_fired(&"darts", targets.size())

func _fire_orbiting_blades() -> void:
	var blade_radius: float = 76.0 + float(replicated_blade_level) * 13.0 + (24.0 if replicated_blade_evolved else 0.0)
	var blade_damage: float = replicated_weapon_damage * (0.3 + 0.075 * float(replicated_blade_level)) * (1.35 if replicated_blade_evolved else 1.0) * (1.0 + replicated_personal_damage_bonus + replicated_team_damage_bonus)
	var hit_count: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy == null or not enemy.alive or enemy.global_position.distance_squared_to(global_position) > blade_radius * blade_radius:
			continue
		enemy.take_damage(blade_damage, peer_id)
		hit_count += 1
	if hit_count > 0:
		var trail_position: Vector2 = global_position + Vector2.RIGHT.rotated(float(Time.get_ticks_msec()) * 0.003) * blade_radius
		_visual.replicate_weapon_trail.rpc(trail_position, 1)
		notify_weapon_fired(&"blades", hit_count)

func _refresh_upgrade_choices() -> void:
	if not multiplayer.is_server():
		return
	if _progression.upgrade_tokens <= 0:
		replicated_upgrade_choices = PackedInt32Array()
		return
	var pool: Array[int] = []
	if replicated_weapon_level < 5:
		pool.append(0)
	if not replicated_attack_speed_passive:
		pool.append(1)
	pool.append(2)
	if replicated_dart_level < 5:
		pool.append(3)
	if replicated_blade_level < 5:
		pool.append(4)
	if replicated_personal_damage_bonus < 0.54:
		pool.append(5)
	if replicated_move_speed < 380.0:
		pool.append(6)
	if replicated_lifesteal < 0.18:
		pool.append(7)
	if replicated_kill_burst_level < 3:
		pool.append(8)
	if replicated_ultimate_cooldown_reduction < 0.3:
		pool.append(9)
	if replicated_pulse_echo_level < 3:
		pool.append(10)
	if replicated_damage_reduction < 0.24:
		pool.append(11)
	if replicated_kill_momentum_level < 3:
		pool.append(12)
	pool.shuffle()
	replicated_upgrade_choices = PackedInt32Array()
	for index: int in range(mini(3, pool.size())):
		replicated_upgrade_choices.append(pool[index])

func _update_auto_target() -> void:
	if not multiplayer.is_server():
		return
	var best_distance_squared: float = replicated_attack_range * replicated_attack_range
	var best_target: BaseEnemy
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy == null or not enemy.alive:
			continue
		var distance_squared: float = global_position.distance_squared_to(enemy.global_position)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_target = enemy
	_attack_target = best_target
	if is_instance_valid(best_target):
		replicated_facing = (best_target.global_position - global_position).normalized()

func get_auto_target() -> BaseEnemy:
	return _attack_target if is_instance_valid(_attack_target) else null

func get_ultimate_name() -> String:
	if _ultimate_definition == null:
		_ultimate_definition = UltimateCatalog.for_character(character_id)
	return _ultimate_definition.display_name

func get_ultimate_cooldown() -> float:
	if _ultimate_definition == null:
		_ultimate_definition = UltimateCatalog.for_character(character_id)
	return _ultimate_definition.cooldown * (1.0 - replicated_ultimate_cooldown_reduction)

func get_weapon_evolution_name() -> String:
	return WeaponEvolutionCatalog.name_for(character_id)

func trigger_attack_animation() -> void:
	if not multiplayer.is_server() or _dead:
		return
	_attack_animation_left = 0.4
	replicated_animation = &"attack"
	_visual.set_animation_state(replicated_animation, replicated_facing)

func notify_enemy_killed(enemy: BaseEnemy) -> void:
	if multiplayer.is_server() and is_instance_valid(enemy):
		on_enemy_killed.emit(enemy, enemy.global_position)
		if replicated_kill_momentum_level > 0:
			grant_passive_momentum(4.0 + float(replicated_kill_momentum_level - 1), 0.16 + 0.04 * float(replicated_kill_momentum_level - 1))
		_trigger_kill_explosion(enemy.global_position)

func notify_weapon_fired(weapon_id: StringName, hit_count: int) -> void:
	if multiplayer.is_server() and hit_count > 0:
		on_weapon_fired.emit(weapon_id, hit_count)
		if weapon_id == &"pulse" and replicated_pulse_echo_level > 0:
			_pulse_echo_progress += 1
			var shots_required: int = maxi(2, 5 - replicated_pulse_echo_level)
			if _pulse_echo_progress >= shots_required:
				_pulse_echo_progress = 0
				fire_passive_echo()

func record_damage_dealt(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0 or replicated_lifesteal <= 0.0 or replicated_dead or replicated_downed:
		return
	_health.heal(amount * replicated_lifesteal)

func _trigger_kill_explosion(origin: Vector2) -> void:
	if not multiplayer.is_server() or replicated_kill_burst_level <= 0 or _kill_explosion_active:
		return
	_kill_explosion_active = true
	var radius: float = 118.0 + float(replicated_kill_burst_level) * 18.0
	var damage: float = replicated_weapon_damage * (0.4 + 0.15 * float(replicated_kill_burst_level))
	damage *= 1.0 + replicated_personal_damage_bonus + replicated_team_damage_bonus
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy != null and enemy.alive and enemy.global_position.distance_squared_to(origin) <= radius * radius:
			enemy.take_damage(damage, peer_id)
	_replicate_kill_explosion.rpc(origin, radius, replicated_kill_burst_level)
	_kill_explosion_active = false

@rpc("authority", "call_local", "unreliable")
func _replicate_kill_explosion(origin: Vector2, radius: float, level: int) -> void:
	if NetworkManager.is_dedicated_mode():
		return
	var effect: Node2D = Node2D.new()
	effect.set_script(ANIMATED_EFFECT_SCRIPT)
	effect.set("texture_path", "res://art/external/combat_fx/fire_burst_48x48_8f.png")
	effect.set("frame_size", 48)
	effect.set("frame_count", 8)
	effect.set("playback_fps", 18.0)
	effect.set("effect_scale", maxf(1.7, radius / 34.0))
	effect.set("tint", Color("#ff8a48") if level > 1 else Color("#ffd17e"))
	effect.position = origin
	var world: Node = get_tree().get_first_node_in_group("session_world")
	if is_instance_valid(world):
		world.get_node("Actors").add_child(effect)

func grant_passive_momentum(duration: float, bonus: float) -> void:
	if not multiplayer.is_server() or replicated_dead or replicated_downed:
		return
	_passive_momentum_left = maxf(_passive_momentum_left, duration)
	replicated_passive_move_bonus = maxf(replicated_passive_move_bonus, bonus)

func fire_passive_echo() -> void:
	if not multiplayer.is_server() or replicated_dead or replicated_downed or replicated_player_paused:
		return
	var targets: Array[BaseEnemy] = _nearest_enemies(620.0, 1)
	if targets.is_empty():
		return
	var target: BaseEnemy = targets[0]
	var damage: float = replicated_weapon_damage * (0.48 + 0.16 * float(replicated_pulse_echo_level)) * (1.0 + replicated_personal_damage_bonus + replicated_team_damage_bonus)
	target.take_damage(damage, peer_id)
	_visual.replicate_weapon_trail.rpc(target.global_position, 0)
	trigger_attack_animation()
	notify_weapon_fired(&"passive_echo", 1)

func heal_lowest_ally(ratio: float) -> void:
	if not multiplayer.is_server():
		return
	var lowest: Player
	var lowest_ratio: float = INF
	for node: Node in get_tree().get_nodes_in_group("players"):
		var ally: Player = node as Player
		if ally == null or ally.replicated_dead or ally.replicated_downed or ally.replicated_health <= 0.0:
			continue
		var health_ratio: float = ally.replicated_health / maxf(1.0, ally.replicated_max_health)
		if health_ratio < lowest_ratio:
			lowest = ally
			lowest_ratio = health_ratio
	if lowest != null:
		lowest._health.heal(lowest.replicated_max_health * clampf(ratio, 0.0, 0.25))

func heal_from_passive(ratio: float) -> void:
	if multiplayer.is_server() and not replicated_dead and not replicated_downed:
		_health.heal(replicated_max_health * clampf(ratio, 0.0, 0.2))

func grant_xp(amount: int) -> void:
	if not multiplayer.is_server() or amount <= 0 or _dead:
		return
	var previous_tokens: int = _progression.upgrade_tokens
	_progression.add_xp(amount)
	if _progression.upgrade_tokens > previous_tokens or replicated_upgrade_choices.is_empty():
		_refresh_upgrade_choices()

func grant_shared_upgrade_token() -> void:
	if not multiplayer.is_server() or replicated_dead:
		return
	_progression.grant_upgrade_token()
	if replicated_upgrade_choices.is_empty():
		_refresh_upgrade_choices()

func request_upgrade(choice: int) -> void:
	if multiplayer.is_server():
		_apply_upgrade(choice)
	else:
		_request_upgrade.rpc_id(1, choice)

func set_local_paused(paused: bool) -> void:
	if multiplayer.is_server():
		replicated_player_paused = paused
	else:
		_request_player_pause.rpc_id(1, paused)

@rpc("any_peer", "call_remote", "reliable")
func _request_player_pause(paused: bool) -> void:
	if multiplayer.is_server() and multiplayer.get_remote_sender_id() == peer_id and (not replicated_dead or not paused):
		replicated_player_paused = paused

@rpc("any_peer", "call_local", "reliable")
func _request_upgrade(choice: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != peer_id:
		return
	_apply_upgrade(choice)

func _apply_upgrade(choice: int) -> void:
	if not multiplayer.is_server() or not replicated_upgrade_choices.has(choice) or replicated_downed or replicated_dead:
		return
	if not _progression.consume_upgrade():
		return
	match choice:
		0:
			_apply_weapon_level()
		1:
			replicated_attack_speed_passive = true
			replicated_attack_cooldown = maxf(0.35, replicated_attack_cooldown * 0.85)
			_check_weapon_evolution()
		2:
			_health.increase_maximum(30.0, 30.0)
		3:
			replicated_dart_level = mini(5, replicated_dart_level + 1)
			_check_weapon_evolution()
		4:
			replicated_blade_level = mini(5, replicated_blade_level + 1)
			_check_weapon_evolution()
		5:
			replicated_personal_damage_bonus = minf(0.54, replicated_personal_damage_bonus + 0.18)
			_check_weapon_evolution()
		6:
			replicated_move_speed = minf(380.0, replicated_move_speed * 1.10)
		7:
			replicated_lifesteal = minf(0.18, replicated_lifesteal + 0.06)
		8:
			replicated_kill_burst_level = mini(3, replicated_kill_burst_level + 1)
		9:
			replicated_ultimate_cooldown_reduction = minf(0.3, replicated_ultimate_cooldown_reduction + 0.1)
			replicated_ultimate_damage_bonus += 0.3
		10:
			replicated_pulse_echo_level = mini(3, replicated_pulse_echo_level + 1)
		11:
			replicated_damage_reduction = minf(0.24, replicated_damage_reduction + 0.08)
			_health.increase_maximum(25.0, 25.0)
		12:
			replicated_kill_momentum_level = mini(3, replicated_kill_momentum_level + 1)
	_refresh_upgrade_choices()

func apply_damage(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0 or replicated_dead or replicated_downed or _damage_invulnerability_left > 0.0:
		return
	_damage_invulnerability_left = 0.35
	_health.apply_damage(amount * (1.0 - replicated_damage_reduction))
	if replicated_health <= 0.0:
		_enter_downed()

func _update_local_facing(movement: Vector2) -> void:
	var best_distance: float = replicated_attack_range * replicated_attack_range
	var local_target: BaseEnemy
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy == null or not enemy.alive:
			continue
		var distance: float = global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			local_target = enemy
	if is_instance_valid(local_target):
		replicated_facing = (local_target.global_position - global_position).normalized()
	elif movement.length_squared() > 0.01:
		replicated_facing = movement.normalized()

func _update_animation() -> void:
	if _dead:
		replicated_animation = &"death"
	elif _attack_animation_left > 0.0:
		replicated_animation = &"attack"
	elif velocity.length_squared() > 4.0:
		replicated_animation = &"run"
	else:
		replicated_animation = &"idle"
	_visual.set_animation_state(replicated_animation, replicated_facing)

func _configure_synchronizer() -> void:
	_synchronizer.root_path = NodePath("..")
	_synchronizer.replication_interval = 0.05
	_synchronizer.delta_interval = 0.05
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	_add_sync_property(config, ".:replicated_position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_input_ack", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_facing", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_health", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_max_health", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_xp", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_xp_to_next", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_upgrade_tokens", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_weapon_damage", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_attack_range", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_attack_cooldown", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_move_speed", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_animation", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_downed", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_dead", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_player_paused", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_bleedout_left", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_revive_progress", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_reviver_peer_id", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_respawn_at", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_ultimate_cooldown_left", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_skill_cooldown_left", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_pulse_cooldown_left", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_dart_cooldown_left", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_blade_cooldown_left", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_add_sync_property(config, ".:replicated_damage_reduction", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_ultimate_cooldown_reduction", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_equipment_levels", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_ultimate_duration_bonus", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_weapon_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_attack_speed_passive", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_weapon_evolved", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_dart_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_dart_evolved", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_blade_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_blade_evolved", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_personal_damage_bonus", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_lifesteal", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_kill_burst_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_ultimate_damage_bonus", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_pulse_echo_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_kill_momentum_level", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_passive_move_bonus", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_upgrade_choices", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_team_damage_bonus", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_team_speed_bonus", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	_add_sync_property(config, ".:replicated_team_buff_left", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	_synchronizer.replication_config = config

func _add_sync_property(config: SceneReplicationConfig, path_text: String, mode: int) -> void:
	var path: NodePath = NodePath(path_text)
	config.add_property(path)
	config.property_set_replication_mode(path, mode)
	config.property_set_spawn(path, true)
