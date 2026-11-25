extends RefCounted
class_name GameMapCatalog

const MAP_IDS: Array[StringName] = [&"neon_district", &"biosynth_garden", &"orbital_foundry"]

static func all_ids() -> Array[StringName]:
	return MAP_IDS.duplicate()

static func id_at(index: int) -> StringName:
	return MAP_IDS[clampi(index, 0, MAP_IDS.size() - 1)]

static func index_for(map_id: StringName) -> int:
	var index: int = MAP_IDS.find(map_id)
	return maxi(0, index)

static func sanitize(map_id: StringName) -> StringName:
	return map_id if MAP_IDS.has(map_id) else MAP_IDS[0]

static func background_path(map_id: StringName) -> String:
	match sanitize(map_id):
		&"biosynth_garden":
			return "res://art/processed/biosynth_garden_arena.png"
		&"orbital_foundry":
			return "res://art/processed/orbital_foundry_arena.png"
	return "res://art/processed/neon_city_arena.png"

static func display_name(map_id: StringName) -> String:
	match sanitize(map_id):
		&"biosynth_garden":
			return "JARDÍN DE BIOSÍNTESIS"
		&"orbital_foundry":
			return "FUNDICIÓN ORBITAL"
	return "DISTRITO NEÓN"

static func rule_summary(map_id: StringName) -> String:
	match sanitize(map_id):
		&"biosynth_garden":
			return "Enemigos resistentes y lentos · oleadas espaciadas"
		&"orbital_foundry":
			return "Horda veloz y densa · élites más frecuentes"
	return "Incursión equilibrada · ritmo estándar"

static func accent_color(map_id: StringName) -> Color:
	match sanitize(map_id):
		&"biosynth_garden":
			return Color("#70e0b0")
		&"orbital_foundry":
			return Color("#f6a24c")
	return Color("#42d8e2")

static func spawn_rate_multiplier(map_id: StringName) -> float:
	match sanitize(map_id):
		&"biosynth_garden":
			return 0.88
		&"orbital_foundry":
			return 1.18
	return 1.0

static func enemy_health_multiplier(map_id: StringName) -> float:
	match sanitize(map_id):
		&"biosynth_garden":
			return 1.18
		&"orbital_foundry":
			return 0.90
	return 1.0

static func enemy_speed_multiplier(map_id: StringName) -> float:
	match sanitize(map_id):
		&"biosynth_garden":
			return 0.90
		&"orbital_foundry":
			return 1.12
	return 1.0

static func miniboss_interval(map_id: StringName) -> float:
	match sanitize(map_id):
		&"biosynth_garden":
			return 105.0
		&"orbital_foundry":
			return 75.0
	return 90.0
