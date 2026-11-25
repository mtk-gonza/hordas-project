extends EnemyModifierBase
class_name HealingAuraComponent

const AURA_RADIUS: float = 156.0
const HEAL_INTERVAL: float = 0.8
const HEAL_RATIO: float = 0.065

var _heal_left: float = 0.0

func server_tick(delta: float, _target: Player, neighbors: Array) -> void:
	if enemy == null:
		return
	_heal_left = maxf(0.0, _heal_left - delta)
	if _heal_left > 0.0:
		return
	_heal_left = HEAL_INTERVAL
	for candidate: Variant in neighbors:
		var ally: BaseEnemy = candidate as BaseEnemy
		if ally == null or ally == enemy or not ally.alive or ally.is_boss or ally.is_miniboss:
			continue
		if ally.global_position.distance_squared_to(enemy.global_position) <= AURA_RADIUS * AURA_RADIUS:
			ally.health = minf(ally.max_health, ally.health + ally.max_health * HEAL_RATIO)
			ally.set_aura_guard(0.45)
			ally._replicate_hit.rpc(ally.health)
