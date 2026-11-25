extends Node
class_name HealthComponent

var maximum_health: float = 100.0
var current_health: float = 100.0

signal health_changed(current: float, maximum: float)
signal depleted

func initialize(maximum: float) -> void:
	maximum_health = maxf(1.0, maximum)
	current_health = maximum_health
	health_changed.emit(current_health, maximum_health)

func apply_damage(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(0.0, current_health - amount)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		depleted.emit()

func heal(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(maximum_health, current_health + amount)
	health_changed.emit(current_health, maximum_health)

func increase_maximum(amount: float, heal_amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0:
		return
	maximum_health += amount
	current_health = minf(maximum_health, current_health + maxf(0.0, heal_amount))
	health_changed.emit(current_health, maximum_health)

func set_replicated_health(value: float) -> void:
	current_health = clampf(value, 0.0, maximum_health)
	health_changed.emit(current_health, maximum_health)

func set_replicated_maximum(value: float) -> void:
	maximum_health = maxf(1.0, value)
	current_health = minf(current_health, maximum_health)
	health_changed.emit(current_health, maximum_health)
