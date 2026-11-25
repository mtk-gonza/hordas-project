extends Resource
class_name AccountProfile

@export var schema_version: int = 1
@export var gold: int = 0
@export var upgrades: Dictionary = {"damage": 0, "health": 0, "speed": 0, "duration": 0}

func to_save_dictionary() -> Dictionary:
	return {
		"version": schema_version,
		"gold": maxi(0, gold),
		"upgrades": upgrades.duplicate(true)
	}

func load_save_dictionary(data: Dictionary, maximum_level: int) -> bool:
	if int(data.get("version", -1)) != schema_version:
		return false
	var saved_upgrades: Variant = data.get("upgrades", null)
	if not saved_upgrades is Dictionary:
		return false
	var source: Dictionary = saved_upgrades as Dictionary
	for upgrade_id: String in ["damage", "health", "speed", "duration"]:
		if not source.has(upgrade_id):
			return false
	gold = clampi(int(data.get("gold", 0)), 0, 2_000_000_000)
	upgrades = {}
	for upgrade_id: String in ["damage", "health", "speed", "duration"]:
		upgrades[upgrade_id] = clampi(int(source[upgrade_id]), 0, maximum_level)
	return true
