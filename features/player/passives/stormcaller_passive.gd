extends CharacterPassiveBase
class_name StormcallerPassive

var _weapon_events: int = 0

func _on_weapon_fired(_weapon_id: StringName, hit_count: int) -> void:
	if not multiplayer.is_server() or owner_player == null or hit_count <= 0:
		return
	if _weapon_id == &"passive_echo":
		return
	_weapon_events += 1
	if _weapon_events >= 5:
		_weapon_events = 0
		owner_player.fire_passive_echo()
