extends Area2D
class_name CircularPulse

const PULSE_RING_SCRIPT: Script = preload("res://features/weapons/pulse_ring.gd")
const EVOLUTION_CATALOG_SCRIPT: Script = preload("res://features/weapons/weapon_evolution_catalog.gd")

@export var base_damage: float = 16.0
@export var base_cooldown: float = 1.05
@export var base_radius: float = 118.0

var _cooldown_left: float = 0.0
var _evolved_echoes_left: int = 0
var _evolved_echoes_total: int = 0
var _evolved_echo_timer: float = 0.0
var _evolved_theme: Dictionary = {}
@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	monitoring = true
	monitorable = false
	var circle: CircleShape2D = _shape.shape.duplicate() as CircleShape2D
	if circle != null:
		circle.radius = base_radius
		_shape.shape = circle
	set_physics_process(multiplayer.is_server())

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if _evolved_echoes_left > 0:
		_evolved_echo_timer -= delta
		if _evolved_echo_timer <= 0.0:
			_fire_evolved_echo()
	var owner_player: Node = get_parent().get_parent()
	if owner_player != null:
		owner_player.set("replicated_pulse_cooldown_left", _cooldown_left)
	if owner_player != null and owner_player.call("get_auto_target") != null:
		try_fire()

func try_fire() -> void:
	if not multiplayer.is_server() or _cooldown_left > 0.0:
		return
	var owner_player: Node = get_parent().get_parent()
	if owner_player == null or bool(owner_player.get("replicated_player_paused")):
		return
	var target: BaseEnemy = owner_player.call("get_auto_target") as BaseEnemy
	if target == null or not is_instance_valid(target):
		return
	var attack_range: float = float(owner_player.get("replicated_attack_range"))
	var attack_cooldown: float = float(owner_player.get("replicated_attack_cooldown"))
	var weapon_damage: float = float(owner_player.get("replicated_weapon_damage")) * (1.0 + float(owner_player.get("replicated_personal_damage_bonus")) + float(owner_player.get("replicated_team_damage_bonus")))
	var evolved: bool = bool(owner_player.get("replicated_weapon_evolved"))
	var source_peer: int = int(owner_player.get("peer_id"))
	_cooldown_left = maxf(0.15, attack_cooldown)
	owner_player.set("replicated_pulse_cooldown_left", _cooldown_left)
	var circle: CircleShape2D = _shape.shape as CircleShape2D
	if circle != null:
		circle.radius = attack_range
	var pulse_hits: Array[BaseEnemy] = _damage_enemies_in_radius(weapon_damage, source_peer, attack_range, owner_player.global_position)
	owner_player.call("notify_weapon_fired", &"pulse", pulse_hits.size())
	if evolved:
		_evolved_theme = EVOLUTION_CATALOG_SCRIPT.for_character(StringName(owner_player.get("character_id")))
		_evolved_echoes_total = int(_evolved_theme.get("echoes", 2))
		_evolved_echoes_left = _evolved_echoes_total
		_evolved_echo_timer = float(_evolved_theme.get("interval", 0.24))
	_replicate_pulse_effect.rpc(attack_range, evolved, Color(_evolved_theme.get("color", Color("#ffd17e"))))
	owner_player.call("trigger_attack_animation")
	pulse_fired.emit(global_position)

func _fire_evolved_echo() -> void:
	_evolved_echoes_left -= 1
	_evolved_echo_timer = float(_evolved_theme.get("interval", 0.24))
	var owner_player: Node = get_parent().get_parent()
	if owner_player == null or not is_instance_valid(owner_player):
		_evolved_echoes_left = 0
		return
	var radius: float = float(owner_player.get("replicated_attack_range")) * float(_evolved_theme.get("radius_scale", 1.0))
	var shape: CircleShape2D = _shape.shape as CircleShape2D
	if shape != null:
		shape.radius = radius
	var damage: float = float(owner_player.get("replicated_weapon_damage"))
	damage *= float(_evolved_theme.get("damage_scale", 0.25)) * (1.0 + float(owner_player.get("replicated_team_damage_bonus")))
	var hits: Array[BaseEnemy] = _damage_enemies_in_radius(damage, int(owner_player.get("peer_id")), radius, owner_player.global_position)
	var knockback: float = float(_evolved_theme.get("knockback", 0.0))
	if knockback > 0.0:
		for enemy: BaseEnemy in hits:
			var direction: Vector2 = enemy.global_position - owner_player.global_position
			if direction.length_squared() > 0.01:
				enemy.global_position += direction.normalized() * knockback * (0.35 if enemy.is_boss else 1.0)
	if not hits.is_empty() and float(_evolved_theme.get("heal_ratio", 0.0)) > 0.0:
		var health: HealthComponent = owner_player.get_node("Health") as HealthComponent
		health.heal(float(owner_player.get("replicated_max_health")) * float(_evolved_theme["heal_ratio"]))
	_replicate_pulse_effect.rpc(radius, true, Color(_evolved_theme.get("color", Color.WHITE)))

func _damage_enemies_in_radius(damage: float, source_peer: int, radius: float, origin: Vector2) -> Array[BaseEnemy]:
	var hit_ids: Dictionary = {}
	var hit_enemies: Array[BaseEnemy] = []
	var radius_squared: float = radius * radius
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy == null or not enemy.alive or hit_ids.has(enemy.net_id):
			continue
		if enemy.global_position.distance_squared_to(origin) > radius_squared:
			continue
		hit_ids[enemy.net_id] = true
		enemy.take_damage(damage, source_peer)
		hit_enemies.append(enemy)
	return hit_enemies

@rpc("authority", "call_local", "unreliable")
func _replicate_pulse_effect(radius: float, evolved: bool, evolution_color: Color) -> void:
	if NetworkManager.is_dedicated_mode():
		return
	var ring: Node2D = Node2D.new()
	ring.set_script(PULSE_RING_SCRIPT)
	ring.set("max_radius", radius * (1.15 if evolved else 1.0))
	ring.set("evolved", evolved)
	ring.set("evolution_color", evolution_color)
	if evolved:
		ring.set("duration", 0.48)
	add_child(ring)

signal pulse_fired(world_position: Vector2)
