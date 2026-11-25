extends Node
class_name CharacterPassiveBase

var owner_player: Player

func _ready() -> void:
	owner_player = get_parent() as Player
	if owner_player == null:
		return
	owner_player.on_enemy_killed.connect(_on_enemy_killed)
	owner_player.on_weapon_fired.connect(_on_weapon_fired)

func _on_enemy_killed(_enemy: BaseEnemy, _position: Vector2) -> void:
	pass

func _on_weapon_fired(_weapon_id: StringName, _hit_count: int) -> void:
	pass
