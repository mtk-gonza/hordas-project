extends EnemyModifierBase
class_name DirectionalShieldComponent

const BLOCK_DOT_THRESHOLD: float = 0.42
const REDUCTION: float = 0.78

func modify_damage(amount: float, source_peer: int) -> float:
	if enemy == null or source_peer < 0:
		return amount
	var source: Player = enemy.get_player_by_peer(source_peer)
	if source == null:
		return amount
	var to_source: Vector2 = (source.global_position - enemy.global_position).normalized()
	var facing: Vector2 = enemy.facing_direction.normalized()
	if facing.length_squared() < 0.01:
		return amount
	if facing.dot(to_source) >= BLOCK_DOT_THRESHOLD:
		return amount * (1.0 - REDUCTION)
	return amount
