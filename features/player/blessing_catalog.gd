extends RefCounted
class_name BlessingCatalog

const BLESSINGS: Array[Dictionary] = [
	{"title": "ARMA EVOLUTIVA", "description": "+12% daño del pulso y +8 de alcance. Nivel 5 + Cadencia desbloquea su evolución.", "icon": "res://art/external/item_icons/dagger_iron.png"},
	{"title": "RITMO IMPARABLE", "description": "El pulso ataca 15% más rápido y habilita la evolución de arma.", "icon": "res://art/external/item_icons/ring_gold_ruby.png"},
	{"title": "CORAZÓN DE TITÁN", "description": "+30 vida máxima y recupera 30 de vida al instante.", "icon": "res://art/external/item_icons/amulet_onyx.png"},
	{"title": "SALVA DE CAZADOR", "description": "Sube Dardos. En nivel 3 dispara un proyectil adicional; en nivel 5 evoluciona con Cadencia.", "icon": "res://art/external/skill_icons/skill_multishot.png"},
	{"title": "DANZA DE HOJAS", "description": "Sube Hojas. Cada nivel amplía su órbita y daño; nivel 5 evoluciona con Poder.", "icon": "res://art/external/skill_icons/skill_whirlwind.png"},
	{"title": "PODER RÚNICO", "description": "+18% de daño para todas tus armas y definitivas. Se acumula hasta 54%.", "icon": "res://art/external/item_icons/dagger_iron.png"},
	{"title": "PASO FANTASMA", "description": "+10% velocidad de movimiento. Rodea la horda y vuelve a la formación.", "icon": "res://art/external/item_icons/boots_winged.png"},
	{"title": "SED DE SANGRE", "description": "Recuperas 6% del daño que infliges. Se acumula hasta 18%.", "icon": "res://art/external/item_icons/amulet_onyx.png"},
	{"title": "CADENA EXPLOSIVA", "description": "Cada baja detona un área de fuego: 55% del daño de arma a los enemigos cercanos.", "icon": "res://art/external/skill_icons/skill_power_slash.png"},
	{"title": "SOBRECARGA ARCANA", "description": "+30% daño de definitiva y 10% menos enfriamiento. Se acumula tres veces.", "icon": "res://art/external/skill_icons/ultimate_fire.png"},
	{"title": "ECO DEL CAZADOR", "description": "Cada 4 pulsos acierta un eco adicional al enemigo más cercano. Más cargas lo activan antes.", "icon": "res://art/external/skill_icons/skill_multishot.png"},
	{"title": "BASTIÓN DE HIERRO", "description": "+8% reducción de daño y +25 vida máxima. Se acumula hasta tres veces.", "icon": "res://art/external/item_icons/shield_round_iron.png"},
	{"title": "IMPULSO CARMESÍ", "description": "Cada baja te da +16% velocidad durante 4 s. Las cargas potencian el impulso.", "icon": "res://art/external/item_icons/boots_winged.png"}
]

static func get_blessing(choice_id: int) -> Dictionary:
	if choice_id < 0 or choice_id >= BLESSINGS.size():
		return {}
	return BLESSINGS[choice_id]

static func display_text(choice_id: int) -> String:
	var blessing: Dictionary = get_blessing(choice_id)
	if blessing.is_empty():
		return "MEJORA\nElige una bendición de combate."
	return "%s\n%s" % [String(blessing["title"]), String(blessing["description"])]

static func icon_path(choice_id: int) -> String:
	var blessing: Dictionary = get_blessing(choice_id)
	return String(blessing.get("icon", ""))
