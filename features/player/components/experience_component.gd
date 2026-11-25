extends Node
class_name ExperienceComponent

var current_xp: int = 0
var current_level: int = 1
var xp_to_next: int = 100
var upgrade_tokens: int = 0

signal leveled_up(level: int)

func initialize() -> void:
	current_xp = 0
	current_level = 1
	xp_to_next = 100
	upgrade_tokens = 0

func add_xp(amount: int) -> void:
	if not multiplayer.is_server() or amount <= 0:
		return
	current_xp += amount
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		current_level += 1
		upgrade_tokens += 1
		xp_to_next = 100 + (current_level - 1) * 25
		leveled_up.emit(current_level)

func consume_upgrade() -> bool:
	if not multiplayer.is_server() or upgrade_tokens <= 0:
		return false
	upgrade_tokens -= 1
	return true

func grant_upgrade_token() -> void:
	if multiplayer.is_server():
		upgrade_tokens += 1

func set_replicated_xp(value: int) -> void:
	current_xp = max(0, value)

func set_replicated_level(value: int) -> void:
	current_level = maxi(1, value)

func set_replicated_xp_to_next(value: int) -> void:
	xp_to_next = maxi(1, value)

func set_replicated_upgrade_tokens(value: int) -> void:
	upgrade_tokens = maxi(0, value)
