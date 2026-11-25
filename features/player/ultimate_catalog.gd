extends RefCounted
class_name UltimateCatalog

const DEFINITIONS: Array[UltimateDefinition] = [
	preload("res://features/player/ultimates/sunburst.tres"),
	preload("res://features/player/ultimates/stormcall.tres"),
	preload("res://features/player/ultimates/moonfall.tres"),
	preload("res://features/player/ultimates/verdant_pulse.tres")
]

static func for_character(character_id: StringName) -> UltimateDefinition:
	match character_id:
		&"stormcaller":
			return DEFINITIONS[1]
		&"moonkeeper":
			return DEFINITIONS[2]
		&"grovekeeper":
			return DEFINITIONS[3]
		_:
			return DEFINITIONS[0]

