extends EnemyModifierBase
class_name SuicideExplosiveComponent

const DETONATION_RADIUS: float = 108.0
const DETONATION_DAMAGE: float = 28.0

var _detonated: bool = false

func server_tick(_delta: float, target: Player, _neighbors: Array) -> void:
	if _detonated or enemy == null or target == null:
		return
	if enemy.global_position.distance_squared_to(target.global_position) > 28.0 * 28.0:
		return
	_detonated = true
	enemy.show_elite_burst.rpc(enemy.global_position, DETONATION_RADIUS)
	for node: Node in enemy.get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player == null or player.replicated_downed or player.replicated_dead or player.replicated_health <= 0.0:
			continue
		if player.global_position.distance_squared_to(enemy.global_position) <= DETONATION_RADIUS * DETONATION_RADIUS:
			player.apply_damage(DETONATION_DAMAGE * enemy.enrage_damage_multiplier)
	enemy.take_damage(enemy.health + 1.0, -1)
