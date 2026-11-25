extends Control
class_name TeamHUD

const PANEL: Color = Color(0.035, 0.065, 0.075, 0.9)
const EDGE: Color = Color("#65797a")
const PAPER: Color = Color("#f2e6cf")
const MUTED: Color = Color("#9aabaa")
const GOLD: Color = Color("#e6ad5b")
const PLAYER_COLORS: Array[Color] = [Color("#4dd0bf"), Color("#78a9ff"), Color("#f0b35c"), Color("#e87aa8")]
const EQUIPMENT_ICONS: Array[Texture2D] = [
	preload("res://art/external/item_icons/dagger_iron.png"),
	preload("res://art/external/item_icons/shield_round_iron.png"),
	preload("res://art/external/item_icons/boots_winged.png"),
	preload("res://art/external/item_icons/ring_gold_ruby.png"),
	preload("res://art/external/item_icons/amulet_onyx.png")
]
const ULTIMATE_ICONS: Dictionary = {
	&"warden": preload("res://art/external/skill_icons/ultimate_fire.png"),
	&"stormcaller": preload("res://art/external/skill_icons/ultimate_lightning.png"),
	&"moonkeeper": preload("res://art/external/skill_icons/ultimate_shadow.png"),
	&"grovekeeper": preload("res://art/external/skill_icons/ultimate_holy.png")
}
const PULSE_ICON: Texture2D = preload("res://art/external/skill_icons/skill_power_slash.png")
const DART_ICON: Texture2D = preload("res://art/external/skill_icons/skill_multishot.png")
const BLADE_ICON: Texture2D = preload("res://art/external/skill_icons/skill_whirlwind.png")

var world: GameWorld
var _refresh_left: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.12
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(world):
		return
	_draw_team_experience()
	_draw_roster()
	_draw_event_status()
	_draw_minimap()
	_draw_equipment()
	_draw_ability_bar()

func _draw_event_status() -> void:
	var objective: ObjectiveManager = world.objective_manager
	if not is_instance_valid(objective):
		return
	if objective.active_event_kind < 0 and objective.event_result_left <= 0.0:
		return
	var panel: Rect2 = Rect2(360.0, 150.0, 500.0, 50.0)
	_draw_panel(panel)
	var text: String = objective.get_event_kind_name()
	var color: Color = Color("#8de0c2") if objective.active_event_kind == 1 else Color("#edab75")
	if objective.active_event_kind < 0:
		color = Color("#e3c98c")
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 12.0, panel.position.y + 18.0), text, HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 24.0, 10, color)
	if objective.active_event_kind >= 0:
		var ratio: float = clampf(objective.active_event_time_left / 75.0, 0.0, 1.0)
		draw_rect(Rect2(panel.position.x + 12.0, panel.position.y + 29.0, panel.size.x - 24.0, 7.0), Color("#202b2c"), true)
		draw_rect(Rect2(panel.position.x + 12.0, panel.position.y + 29.0, (panel.size.x - 24.0) * ratio, 7.0), color, true)
		var progress_ratio: float = 1.0 - clampf(objective.active_event_health / 120.0, 0.0, 1.0) if objective.active_event_kind == 0 else clampf(objective.active_event_progress / 24.0, 0.0, 1.0)
		draw_rect(Rect2(panel.position.x + 12.0, panel.position.y + 38.0, (panel.size.x - 24.0) * progress_ratio, 3.0), Color("#f2e6cf"), true)

func _draw_team_experience() -> void:
	var panel: Rect2 = Rect2(20.0, 505.0, 324.0, 42.0)
	_draw_panel(panel)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(panel.position.x + 11.0, panel.position.y + 15.0), "ESCUADRÓN  ·  NIVEL %02d" % world.team_level, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, PAPER)
	var bar: Rect2 = Rect2(panel.position.x + 10.0, panel.position.y + 23.0, panel.size.x - 20.0, 10.0)
	draw_rect(bar, Color("#162428"), true)
	var progress: float = clampf(float(world.team_xp) / maxf(1.0, float(world.team_xp_to_next)), 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), Color("#68cdbb"), true)
	draw_string(font, Vector2(panel.position.x + panel.size.x - 11.0, panel.position.y + 15.0), "%d / %d XP" % [world.team_xp, world.team_xp_to_next], HORIZONTAL_ALIGNMENT_RIGHT, -1.0, 9, MUTED)

func _draw_roster() -> void:
	var players: Array[Player] = _sorted_players()
	var panel: Rect2 = Rect2(20.0, 555.0, 324.0, 112.0)
	_draw_panel(panel)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(panel.position.x + 10.0, panel.position.y + 15.0), "ALIADOS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, MUTED)
	for slot: int in range(4):
		var card: Rect2 = Rect2(panel.position.x + 8.0 + float(slot) * 78.0, panel.position.y + 23.0, 74.0, 80.0)
		draw_rect(card, Color("#132126"), true)
		draw_rect(card, Color("#40575b"), false, 1.0)
		if slot >= players.size():
			draw_string(font, Vector2(card.position.x + 8.0, card.position.y + 40.0), "VACÍO", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, MUTED)
			continue
		var player: Player = players[slot]
		var tint: Color = PLAYER_COLORS[posmod(player.peer_id - 1, PLAYER_COLORS.size())]
		var portrait: Texture2D = _portrait_for(player)
		if portrait != null:
			draw_texture_rect(portrait, Rect2(card.position.x + 7.0, card.position.y + 6.0, 34.0, 34.0), false, tint)
		else:
			draw_circle(card.position + Vector2(24.0, 23.0), 16.0, tint)
		var state_color: Color = Color("#e77982") if player.replicated_downed else (Color("#798488") if player.replicated_dead else PAPER)
		var state_text: String = "ABATIDO" if player.replicated_downed else ("CAÍDO" if player.replicated_dead else ("TÚ" if player.peer_id == multiplayer.get_unique_id() else "P%d" % posmod(player.peer_id, 10)))
		draw_string(font, Vector2(card.position.x + 43.0, card.position.y + 18.0), state_text, HORIZONTAL_ALIGNMENT_LEFT, 27.0, 8, state_color)
		var health_rect: Rect2 = Rect2(card.position.x + 7.0, card.position.y + 47.0, card.size.x - 14.0, 6.0)
		draw_rect(health_rect, Color("#263135"), true)
		var health_ratio: float = clampf(player.replicated_health / maxf(1.0, player.replicated_max_health), 0.0, 1.0)
		draw_rect(Rect2(health_rect.position, Vector2(health_rect.size.x * health_ratio, health_rect.size.y)), Color("#d66a62") if player.replicated_downed else Color("#65c99d"), true)
		draw_string(font, Vector2(card.position.x + 7.0, card.position.y + 69.0), "NIVEL %d" % player.replicated_level, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, PAPER)

func _draw_minimap() -> void:
	var panel: Rect2 = Rect2(size.x - 235.0, 18.0, 216.0, 252.0)
	_draw_panel(panel)
	var map: Rect2 = Rect2(panel.position.x + 12.0, panel.position.y + 28.0, 192.0, 174.0)
	draw_rect(map, Color("#0d171b", 0.9), true)
	draw_rect(map, Color("#526567"), false, 1.0)
	var center: Vector2 = map.get_center()
	var map_radius: float = minf(map.size.x, map.size.y) * 0.46
	for division: int in range(-2, 3):
		var x: float = center.x + float(division) * map.size.x * 0.17
		var y: float = center.y + float(division) * map.size.y * 0.17
		draw_line(Vector2(x, map.position.y + 1.0), Vector2(x, map.end.y - 1.0), Color(0.38, 0.49, 0.5, 0.13), 1.0)
		draw_line(Vector2(map.position.x + 1.0, y), Vector2(map.end.x - 1.0, y), Color(0.38, 0.49, 0.5, 0.13), 1.0)
	var map_accent: Color = GameMapCatalog.accent_color(NetworkManager.selected_map_id)
	draw_arc(center, map_radius, 0.0, TAU, 64, map_accent, 1.0)
	var living: Array[Player] = []
	var team_center: Vector2 = Vector2.ZERO
	for player: Player in _sorted_players():
		if not player.replicated_dead and not player.replicated_downed and player.replicated_health > 0.0:
			living.append(player)
			team_center += player.global_position
	if not living.is_empty():
		team_center /= float(living.size())
		var safe_center: Vector2 = _map_point(team_center, center, map_radius)
		var safe_radius: float = map_radius * 520.0 / maxf(1.0, world.arena_radius)
		draw_arc(safe_center, safe_radius, 0.0, TAU, 48, Color(map_accent.r, map_accent.g, map_accent.b, 0.46), 1.0)
	draw_circle(center, 2.5, Color("#e2d5b9"))
	for pillar_position: Vector2 in world.objective_manager.get_pillar_positions():
		var point: Vector2 = _map_point(pillar_position, center, map_radius)
		draw_colored_polygon(PackedVector2Array([point + Vector2(0.0, -4.0), point + Vector2(4.0, 0.0), point + Vector2(0.0, 4.0), point + Vector2(-4.0, 0.0)]), Color("#e3ac5d"))
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var stride: int = maxi(1, ceili(float(enemies.size()) / 90.0))
	for index: int in range(0, enemies.size(), stride):
		var enemy: BaseEnemy = enemies[index] as BaseEnemy
		if enemy == null or not enemy.alive:
			continue
		var enemy_point: Vector2 = _map_point(enemy.global_position, center, map_radius)
		draw_circle(enemy_point, 1.5 if not enemy.is_boss else 3.2, Color("#d9635d") if not enemy.is_boss else Color("#ff6258"))
	for player: Player in _sorted_players():
		var player_color: Color = PLAYER_COLORS[posmod(player.peer_id - 1, PLAYER_COLORS.size())]
		if player.replicated_downed:
			player_color = Color("#ee6978")
		elif player.replicated_dead:
			player_color = Color("#808589")
		var player_point: Vector2 = _map_point(player.global_position, center, map_radius)
		if player.replicated_downed:
			draw_arc(player_point, 6.0, 0.0, TAU, 20, Color("#ed6978"), 1.0)
		var facing: Vector2 = Vector2(player.replicated_facing.x, -player.replicated_facing.y).normalized()
		if facing.length_squared() < 0.1:
			facing = Vector2.UP
		var tip: Vector2 = player_point + facing * 5.5
		var side: Vector2 = facing.orthogonal() * 3.0
		draw_colored_polygon(PackedVector2Array([tip, player_point - facing * 3.0 + side, player_point - facing * 3.0 - side]), player_color)
	var boss: BaseEnemy = _world_boss()
	if boss != null:
		draw_circle(_map_point(boss.global_position, center, map_radius), 5.0, Color("#ff6258"))
	if world.objective_manager.active_event_kind >= 0:
		draw_colored_polygon(PackedVector2Array([_map_point(world.objective_manager.get_event_position(), center, map_radius) + Vector2(0.0, -5.0), _map_point(world.objective_manager.get_event_position(), center, map_radius) + Vector2(5.0, 0.0), _map_point(world.objective_manager.get_event_position(), center, map_radius) + Vector2(0.0, 5.0), _map_point(world.objective_manager.get_event_position(), center, map_radius) + Vector2(-5.0, 0.0)]), Color("#8ce2bc"))
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 11.0, panel.position.y + 17.0), GameMapCatalog.display_name(NetworkManager.selected_map_id), HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 22.0, 8, map_accent)
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 10.0, panel.position.y + 221.0), "● ALIADOS    ● HORDA", HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 20.0, 8, Color("#bdc7b8"))
	draw_circle(panel.position + Vector2(17.0, 238.0), 2.5, Color("#e3ac5d"))
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 23.0, panel.position.y + 241.0), "PILAR", HORIZONTAL_ALIGNMENT_LEFT, 40.0, 7, MUTED)
	draw_circle(panel.position + Vector2(87.0, 238.0), 2.5, Color("#8ce2bc"))
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 93.0, panel.position.y + 241.0), "OBJETIVO", HORIZONTAL_ALIGNMENT_LEFT, 60.0, 7, MUTED)
	draw_arc(panel.position + Vector2(173.0, 237.0), 6.0, 0.0, TAU, 20, Color("#69cbb0"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(panel.position.x + 181.0, panel.position.y + 241.0), "ZONA", HORIZONTAL_ALIGNMENT_LEFT, 32.0, 7, MUTED)

func _draw_equipment() -> void:
	var player: Player = world.get_local_player()
	if player == null:
		return
	var item_width: float = 37.0
	var gap: float = 7.0
	var start_x: float = (size.x - (item_width * 5.0 + gap * 4.0)) * 0.5
	var y: float = size.y - 146.0
	for index: int in range(5):
		var x: float = start_x + float(index) * (item_width + gap)
		var rect: Rect2 = Rect2(x, y, item_width, 34.0)
		var item: Dictionary = EquipmentCatalog.item_for_choice(EquipmentCatalog.FIRST_EQUIPMENT_ID + index)
		var stacks: int = player.get_equipment_stacks(index)
		var tint: Color = item["color"] if stacks > 0 else Color("#425255")
		draw_rect(rect, Color("#101a1e", 0.94), true)
		draw_rect(rect, tint.darkened(0.4) if stacks > 0 else Color("#39494c"), false, 1.0)
		var item_icon: Texture2D = EQUIPMENT_ICONS[index]
		if item_icon != null:
			draw_texture_rect(item_icon, Rect2(rect.position + Vector2(7.0, 4.0), Vector2(23.0, 23.0)), false, tint)
		else:
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 22.0), String(item["glyph"]), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, tint)
		if stacks > 0:
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x - 10.0, 32.0), "×%d" % stacks, HORIZONTAL_ALIGNMENT_RIGHT, 10.0, 8, PAPER)

func _draw_ability_bar() -> void:
	var player: Player = world.get_local_player()
	if player == null:
		return
	var ultimate_icon: Texture2D = ULTIMATE_ICONS.get(player.character_id, ULTIMATE_ICONS[&"warden"]) as Texture2D
	var definitions: Array[Dictionary] = [
		{"key": "E", "name": "CORTE DE ESCUADRÓN", "glyph": "✦", "icon": BLADE_ICON, "color": Color("#62d9e4"), "level": 1, "left": player.replicated_skill_cooldown_left, "max": 10.0},
		{"key": "R", "name": player.get_ultimate_name(), "glyph": "✹", "icon": ultimate_icon, "color": Color("#edb25d"), "level": 1, "left": player.replicated_ultimate_cooldown_left, "max": player.get_ultimate_cooldown()},
		{"key": "AUTO", "name": "PULSO", "glyph": "◉", "icon": PULSE_ICON, "color": Color("#64d4c5"), "level": player.replicated_weapon_level, "left": player.replicated_pulse_cooldown_left, "max": player.replicated_attack_cooldown},
		{"key": "1", "name": "DARDOS", "glyph": "➤", "icon": DART_ICON, "color": Color("#92b8ee"), "level": player.replicated_dart_level, "left": player.replicated_dart_cooldown_left, "max": player.get_dart_cooldown()},
		{"key": "2", "name": "HOJAS", "glyph": "✦", "icon": BLADE_ICON, "color": Color("#d68fba"), "level": player.replicated_blade_level, "left": player.replicated_blade_cooldown_left, "max": player.get_blade_cooldown()}
	]
	var slot_width: float = 75.0
	var slot_height: float = 80.0
	var gap: float = 8.0
	var start_x: float = (size.x - (slot_width * definitions.size() + gap * (definitions.size() - 1))) * 0.5
	var y: float = size.y - 103.0
	for index: int in range(definitions.size()):
		var data: Dictionary = definitions[index]
		var rect: Rect2 = Rect2(start_x + float(index) * (slot_width + gap), y, slot_width, slot_height)
		var unlocked: bool = int(data["level"]) > 0
		var color: Color = data["color"] if unlocked else Color("#566265")
		draw_rect(rect, Color("#0d171b", 0.96), true)
		draw_rect(rect, color.darkened(0.45), false, 1.0)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(0.0, 14.0), String(data["key"]), HORIZONTAL_ALIGNMENT_CENTER, slot_width, 9, GOLD if index < 2 else MUTED)
		var icon_rect: Rect2 = Rect2(rect.position + Vector2(18.0, 19.0), Vector2(39.0, 38.0))
		draw_rect(icon_rect, Color("#17252a"), true)
		draw_circle(icon_rect.get_center(), 14.0, color.darkened(0.55))
		var skill_icon: Texture2D = data["icon"] as Texture2D
		if skill_icon != null:
			draw_texture_rect(skill_icon, Rect2(icon_rect.position + Vector2(7.0, 7.0), Vector2(25.0, 25.0)), false, Color.WHITE if unlocked else Color(0.42, 0.46, 0.47))
		else:
			draw_string(ThemeDB.fallback_font, icon_rect.position + Vector2(0.0, 27.0), String(data["glyph"]), HORIZONTAL_ALIGNMENT_CENTER, icon_rect.size.x, 22, color)
		var maximum: float = maxf(0.01, float(data["max"]))
		var remaining: float = maxf(0.0, float(data["left"]))
		if remaining > 0.0 and unlocked:
			var fraction: float = clampf(remaining / maximum, 0.0, 1.0)
			draw_rect(Rect2(icon_rect.position, Vector2(icon_rect.size.x, icon_rect.size.y * fraction)), Color(0.025, 0.04, 0.05, 0.76), true)
			draw_string(ThemeDB.fallback_font, icon_rect.position + Vector2(0.0, 24.0), "%.1f" % remaining, HORIZONTAL_ALIGNMENT_CENTER, icon_rect.size.x, 11, PAPER)
		elif not unlocked:
			draw_string(ThemeDB.fallback_font, icon_rect.position + Vector2(0.0, 24.0), "—", HORIZONTAL_ALIGNMENT_CENTER, icon_rect.size.x, 14, MUTED)
		var caption: String = "LISTA" if remaining <= 0.0 else "%.0f s" % remaining
		if index > 3 and not unlocked:
			caption = "NO ADQUIRIDA"
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(2.0, 70.0), caption, HORIZONTAL_ALIGNMENT_CENTER, slot_width - 4.0, 8, Color("#75d6b8") if remaining <= 0.0 and unlocked else MUTED)
		if index > 2:
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(slot_width - 17.0, 17.0), "N%d" % int(data["level"]), HORIZONTAL_ALIGNMENT_RIGHT, 15.0, 8, PAPER if unlocked else MUTED)

func _draw_panel(rect: Rect2) -> void:
	draw_rect(rect, PANEL, true)
	draw_rect(rect, EDGE, false, 1.0)

func _sorted_players() -> Array[Player]:
	var result: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null:
			result.append(player)
	result.sort_custom(func(a: Player, b: Player) -> bool: return a.peer_id < b.peer_id)
	return result

func _portrait_for(player: Player) -> Texture2D:
	var visual: PlayerVisual = player.get_node_or_null("Visual") as PlayerVisual
	if visual == null or visual.sprite_frames == null or not visual.sprite_frames.has_animation(&"idle_down"):
		return null
	return visual.sprite_frames.get_frame_texture(&"idle_down", 0)

func _map_point(world_position: Vector2, center: Vector2, radius: float) -> Vector2:
	var normalized: Vector2 = world_position / maxf(1.0, world.arena_radius)
	return center + Vector2(normalized.x, -normalized.y) * radius

func _world_boss() -> BaseEnemy:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: BaseEnemy = node as BaseEnemy
		if enemy != null and enemy.is_boss and enemy.alive:
			return enemy
	return null
