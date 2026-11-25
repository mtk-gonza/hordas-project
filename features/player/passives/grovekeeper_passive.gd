extends CharacterPassiveBase
class_name GrovekeeperPassive

func _on_enemy_killed(_enemy: BaseEnemy, _position: Vector2) -> void:
	if multiplayer.is_server() and owner_player != null:
		owner_player.heal_from_passive(0.035)
