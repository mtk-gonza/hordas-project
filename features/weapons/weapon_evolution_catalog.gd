extends RefCounted
class_name WeaponEvolutionCatalog

const DEFINITIONS: Dictionary = {
	&"warden": {
		"name": "FILO DEL BASTIÓN",
		"echoes": 2,
		"interval": 0.24,
		"damage_scale": 0.28,
		"radius_scale": 1.08,
		"knockback": 18.0,
		"heal_ratio": 0.0,
		"color": Color("#ffd17e")
	},
	&"stormcaller": {
		"name": "TORMENTA DE CENTELLAS",
		"echoes": 3,
		"interval": 0.13,
		"damage_scale": 0.20,
		"radius_scale": 1.22,
		"knockback": 0.0,
		"heal_ratio": 0.0,
		"color": Color("#81d9ff")
	},
	&"moonkeeper": {
		"name": "MAREA LUNAR",
		"echoes": 2,
		"interval": 0.34,
		"damage_scale": 0.23,
		"radius_scale": 1.42,
		"knockback": 8.0,
		"heal_ratio": 0.025,
		"color": Color("#cba6ff")
	},
	&"grovekeeper": {
		"name": "RAÍCES DEL UMBRAL",
		"echoes": 2,
		"interval": 0.40,
		"damage_scale": 0.26,
		"radius_scale": 1.28,
		"knockback": 44.0,
		"heal_ratio": 0.0,
		"color": Color("#91e58d")
	}
}

static func for_character(character_id: StringName) -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(character_id, DEFINITIONS[&"warden"])
	return definition.duplicate(true)

static func name_for(character_id: StringName) -> String:
	return String(for_character(character_id).get("name", "ARMA EVOLUCIONADA"))
