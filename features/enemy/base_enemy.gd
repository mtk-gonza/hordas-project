extends CharacterBody2D
class_name BaseEnemy

const SHIELD_SCRIPT: Script = preload("res://features/enemy/modifiers/directional_shield_component.gd")
const SUICIDE_SCRIPT: Script = preload("res://features/enemy/modifiers/suicide_explosive_component.gd")
const AURA_SCRIPT: Script = preload("res://features/enemy/modifiers/healing_aura_component.gd")

@export var max_health: float = 30.0
@export var move_speed: float = 76.0
@export var separation_radius: float = 34.0
@export var xp_reward: int = 8
@export var contact_damage: float = 8.0
@export var contact_cooldown: float = 0.8

var net_id: int = -1
var archetype: StringName = &"base"
var visual_species: StringName = &""
var elite_modifier: int = 0
var facing_direction: Vector2 = Vector2.RIGHT
var enrage_multiplier: float = 1.0
var enrage_damage_multiplier: float = 1.0
var aura_guard_left: float = 0.0
var health: float = 30.0
var alive: bool = true
var is_boss: bool = false
var is_miniboss: bool = false
var replicated_position: Vector2 = Vector2.ZERO
var _contact_timer: float = 0.0
var _boss_slam_cooldown: float = 4.0
var _boss_slam_windup: float = 0.0
var _boss_slam_center: Vector2 = Vector2.ZERO
var _boss_slam_radius: float = 210.0
var _modifier_component: EnemyModifierBase
var _elite_burst_left: float = 0.0
var _elite_burst_radius: float = 0.0
var _elite_burst_origin: Vector2 = Vector2.ZERO
var _mage_attack_windup: float = 0.0
var _mage_attack_cooldown: float = 2.6
var _mage_attack_target: Vector2 = Vector2.ZERO
var _brute_stomp_windup: float = 0.0
var _brute_stomp_cooldown: float = 4.5

@onready var _visual: EnemyVisual = $Visual
@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

signal died(net_id: int, source_peer: int)
signal despawn_ready(net_id: int)

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	replicated_position = global_position
	_visual.is_boss = is_boss
	_visual.is_miniboss = is_miniboss
	_visual.set_enraged(enrage_multiplier > 1.0)
	var circle: CircleShape2D = _collision_shape.shape.duplicate() as CircleShape2D
	circle.radius = 29.0 if is_boss else 12.0
	_collision_shape.shape = circle
	_visual.queue_redraw()
	_attach_modifier()
	set_physics_process(false)

func server_tick(delta: float, target: CharacterBody2D, neighbors: Array) -> void:
	if not multiplayer.is_server() or not alive or not is_instance_valid(target):
		return
	_contact_timer = maxf(0.0, _contact_timer - delta)
	var target_offset: Vector2 = target.global_position - global_position
	var steering: Vector2 = target_offset.normalized()
	if steering.length_squared() > 0.01:
		facing_direction = steering
	var separation: Vector2 = Vector2.ZERO
	var radius_squared: float = separation_radius * separation_radius
	for candidate: Variant in neighbors:
		var other: BaseEnemy = candidate as BaseEnemy
		if other == null or other == self or not other.alive:
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance_squared: float = offset.length_squared()
		if distance_squared > 0.001 and distance_squared < radius_squared:
			var distance: float = sqrt(distance_squared)
			separation += offset / distance * (1.0 - distance / separation_radius)
	if separation.length_squared() > 0.0:
		steering = (steering + separation.normalized() * 0.9).normalized()
	velocity = steering * move_speed * enrage_multiplier
	move_and_slide()
	replicated_position = global_position
	if target_offset.length_squared() <= 30.0 * 30.0 and _contact_timer <= 0.0:
		target.call("apply_damage", contact_damage * enrage_damage_multiplier)
		_contact_timer = contact_cooldown
		_replicate_action_animation.rpc(&"attack")
	if is_boss:
		_tick_boss_slam(delta, target)
	if archetype == &"mage" or archetype == &"soul_weaver" or archetype == &"storm_mage":
		_tick_mage_attack(delta, target)
	elif archetype == &"plague_brute":
		_tick_brute_stomp(delta)
	aura_guard_left = maxf(0.0, aura_guard_left - delta)
	if is_instance_valid(_modifier_component):
		_modifier_component.server_tick(delta, target, neighbors)

func _tick_boss_slam(delta: float, target: CharacterBody2D) -> void:
	if _boss_slam_windup > 0.0:
		_boss_slam_windup = maxf(0.0, _boss_slam_windup - delta)
		if _boss_slam_windup <= 0.0:
			_resolve_boss_slam()
		return
	_boss_slam_cooldown = maxf(0.0, _boss_slam_cooldown - delta)
	if _boss_slam_cooldown > 0.0 or global_position.distance_squared_to(target.global_position) > 560.0 * 560.0:
		return
	_boss_slam_center = target.global_position
	_boss_slam_radius = 210.0
	_boss_slam_windup = 1.2
	_boss_slam_cooldown = 7.4
	_replicate_action_animation.rpc(&"special" if health <= max_health * 0.5 else &"attack")
	_show_boss_slam_telegraph.rpc(_boss_slam_center, _boss_slam_radius, _boss_slam_windup)

func _tick_mage_attack(delta: float, target: CharacterBody2D) -> void:
	if _mage_attack_windup > 0.0:
		_mage_attack_windup = maxf(0.0, _mage_attack_windup - delta)
		if _mage_attack_windup <= 0.0:
			for node: Node in get_tree().get_nodes_in_group("players"):
				var player: Player = node as Player
				if player == null or player.replicated_downed or player.replicated_dead:
					continue
				if player.global_position.distance_squared_to(_mage_attack_target) <= 42.0 * 42.0:
					player.apply_damage(11.0 * enrage_damage_multiplier)
			_replicate_mage_bolt.rpc(_mage_attack_target)
		return
	_mage_attack_cooldown = maxf(0.0, _mage_attack_cooldown - delta)
	if _mage_attack_cooldown > 0.0:
		return
	var distance_squared: float = global_position.distance_squared_to(target.global_position)
	if distance_squared < 150.0 * 150.0 or distance_squared > 430.0 * 430.0:
		return
	_mage_attack_target = target.global_position
	_mage_attack_windup = 0.82
	_mage_attack_cooldown = 3.4
	_replicate_action_animation.rpc(&"attack")
	_replicate_mage_telegraph.rpc(_mage_attack_target)

func _tick_brute_stomp(delta: float) -> void:
	if _brute_stomp_windup > 0.0:
		_brute_stomp_windup = maxf(0.0, _brute_stomp_windup - delta)
		if _brute_stomp_windup <= 0.0:
			var stomp_radius: float = 118.0
			for node: Node in get_tree().get_nodes_in_group("players"):
				var player: Player = node as Player
				if player == null or player.replicated_downed or player.replicated_dead:
					continue
				if player.global_position.distance_squared_to(global_position) <= stomp_radius * stomp_radius:
					player.apply_damage(contact_damage * 1.15 * enrage_damage_multiplier)
			_replicate_boss_slam.rpc(global_position, stomp_radius)
		return
	_brute_stomp_cooldown = maxf(0.0, _brute_stomp_cooldown - delta)
	if _brute_stomp_cooldown > 0.0:
		return
	_brute_stomp_windup = 0.92
	_brute_stomp_cooldown = 5.2
	_replicate_action_animation.rpc(&"attack")
	_show_boss_slam_telegraph.rpc(global_position, 118.0, _brute_stomp_windup)

func _resolve_boss_slam() -> void:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player == null or player.replicated_downed or player.replicated_dead or player.replicated_health <= 0.0:
			continue
		if player.global_position.distance_squared_to(_boss_slam_center) <= _boss_slam_radius * _boss_slam_radius:
			player.apply_damage(contact_damage * 1.65 * enrage_damage_multiplier)
	_replicate_boss_slam.rpc(_boss_slam_center, _boss_slam_radius)

@rpc("authority", "call_local", "reliable")
func _show_boss_slam_telegraph(center: Vector2, radius: float, windup: float) -> void:
	if is_instance_valid(_visual):
		_visual.show_boss_telegraph(center, radius, windup)

@rpc("authority", "call_local", "reliable")
func _replicate_boss_slam(center: Vector2, radius: float) -> void:
	if is_instance_valid(_visual):
		_visual.show_boss_slam(center, radius)

@rpc("authority", "call_local", "reliable")
func _replicate_mage_telegraph(target: Vector2) -> void:
	if is_instance_valid(_visual):
		_visual.show_mage_telegraph(target)

@rpc("authority", "call_local", "reliable")
func _replicate_mage_bolt(target: Vector2) -> void:
	if is_instance_valid(_visual):
		_visual.show_mage_bolt(target)

func take_damage(amount: float, source_peer: int) -> void:
	if not multiplayer.is_server() or not alive or amount <= 0.0:
		return
	if is_instance_valid(_modifier_component):
		amount = _modifier_component.modify_damage(amount, source_peer)
	if aura_guard_left > 0.0:
		amount *= 0.35
	var health_before: float = health
	health = maxf(0.0, health - amount)
	var attacker: Player = get_player_by_peer(source_peer)
	if attacker != null:
		attacker.record_damage_dealt(health_before - health)
	if health > 0.0:
		_visual.play_hit()
		_replicate_hit.rpc(health)
		return
	alive = false
	var credited_player: Node
	for node: Node in get_tree().get_nodes_in_group("players"):
		if int(node.get("peer_id")) == source_peer:
			credited_player = node
			break
	if credited_player != null:
		credited_player.call("grant_xp", xp_reward)
		credited_player.call("notify_enemy_killed", self)
	var world: GameWorld = get_tree().get_first_node_in_group("session_world") as GameWorld
	if world != null:
		world.grant_team_xp(xp_reward)
	died.emit(net_id, source_peer)
	_visual.play_death()
	_collision_shape.set_deferred("disabled", true)
	_replicate_death.rpc()
	get_tree().create_timer(0.55).timeout.connect(_finish_death)

func get_player_by_peer(source_peer: int) -> Player:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and player.peer_id == source_peer:
			return player
	return null

func set_aura_guard(duration: float) -> void:
	aura_guard_left = maxf(aura_guard_left, duration)

func _attach_modifier() -> void:
	var component_script: Script
	match elite_modifier:
		1:
			component_script = SHIELD_SCRIPT
		2:
			component_script = SUICIDE_SCRIPT
		3:
			component_script = AURA_SCRIPT
		_:
			return
	var component: Node = Node.new()
	component.name = "EliteModifier"
	component.set_script(component_script)
	add_child(component)
	_modifier_component = component as EnemyModifierBase
	_visual.set_elite_modifier(elite_modifier)

func set_enraged(multiplier: float) -> void:
	enrage_multiplier = maxf(1.0, multiplier)
	enrage_damage_multiplier = maxf(1.0, multiplier)
	if is_instance_valid(_visual):
		_visual.set_enraged(enrage_multiplier > 1.0)

@rpc("authority", "call_local", "reliable")
func show_elite_burst(origin: Vector2, radius: float) -> void:
	_elite_burst_origin = origin
	_elite_burst_radius = radius
	_elite_burst_left = 0.42
	if is_instance_valid(_visual):
		_visual.show_elite_burst(origin, radius)

@rpc("authority", "call_remote", "reliable")
func _replicate_death() -> void:
	if multiplayer.is_server():
		return
	alive = false
	_visual.play_death()
	_collision_shape.set_deferred("disabled", true)

@rpc("authority", "call_remote", "unreliable_ordered")
func _replicate_hit(remaining_health: float) -> void:
	if not multiplayer.is_server() and alive:
		health = clampf(remaining_health, 0.0, max_health)
		_visual.play_hit()

@rpc("authority", "call_local", "unreliable")
func _replicate_action_animation(animation_name: StringName) -> void:
	if NetworkManager.is_dedicated_mode() or not is_instance_valid(_visual):
		return
	if animation_name == &"attack":
		_visual.play_attack()
	elif animation_name == &"special":
		_visual.play_special()
	elif animation_name == &"hurt":
		_visual.play_hit()

func _finish_death() -> void:
	despawn_ready.emit(net_id)
	queue_free()
