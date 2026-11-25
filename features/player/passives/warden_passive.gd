extends CharacterPassiveBase
class_name WardenPassive

func _on_enemy_killed(_enemy: BaseEnemy, _position: Vector2) -> void:
	if multiplayer.is_server() and owner_player != null:
		owner_player.grant_passive_momentum(3.0, 0.12)
