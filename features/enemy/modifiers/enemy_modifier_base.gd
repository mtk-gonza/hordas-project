extends Node
class_name EnemyModifierBase

var enemy: BaseEnemy

func _ready() -> void:
	enemy = get_parent() as BaseEnemy

func modify_damage(amount: float, _source_peer: int) -> float:
	return amount

func server_tick(_delta: float, _target: Player, _neighbors: Array) -> void:
	pass
