extends CharacterPassiveBase
class_name MoonkeeperPassive

var _confirmed_hits: int = 0

func _on_weapon_fired(_weapon_id: StringName, hit_count: int) -> void:
	if not multiplayer.is_server() or owner_player == null or hit_count <= 0:
		return
	_confirmed_hits += hit_count
	if _confirmed_hits >= 4:
		_confirmed_hits = posmod(_confirmed_hits, 4)
		owner_player.heal_lowest_ally(0.045)
