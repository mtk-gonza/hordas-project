extends RefCounted
class_name EquipmentCatalog

const MAX_STACKS: int = 3
const FIRST_EQUIPMENT_ID: int = 5
const ITEMS: Array[Dictionary] = [
	{"id": 5, "name": "SIGILO COLMILLO", "glyph": "✦", "color": Color("#e87961"), "description": "+12% daño por carga"},
	{"id": 6, "name": "BROCHE DE HIERRO", "glyph": "⬟", "color": Color("#9cb8c4"), "description": "+20 vida y +8% defensa"},
	{"id": 7, "name": "BOTAS DEL VIENTO", "glyph": "➤", "color": Color("#78c9bd"), "description": "+9% velocidad"},
	{"id": 8, "name": "ANILLO DE CENIZA", "glyph": "◉", "color": Color("#d8a65e"), "description": "+7% daño y cadencia"},
	{"id": 9, "name": "AMULETO ORÁCULO", "glyph": "◇", "color": Color("#9b92df"), "description": "−8% enfriamiento definitivo"}
]

static func is_equipment_choice(choice_id: int) -> bool:
	return choice_id >= FIRST_EQUIPMENT_ID and choice_id < FIRST_EQUIPMENT_ID + ITEMS.size()

static func item_for_choice(choice_id: int) -> Dictionary:
	var index: int = choice_id - FIRST_EQUIPMENT_ID
	if index < 0 or index >= ITEMS.size():
		return {}
	return ITEMS[index]

static func choice_name(choice_id: int) -> String:
	var item: Dictionary = item_for_choice(choice_id)
	if item.is_empty():
		return "MEJORA"
	return "%s\n%s" % [String(item["name"]), String(item["description"])]
