extends CanvasLayer
class_name GameHUD

const INK: Color = Color("#10191e")
const PANEL: Color = Color(0.035, 0.065, 0.075, 0.92)
const EDGE: Color = Color("#667d7f")
const PAPER: Color = Color("#f5e8cf")
const MUTED: Color = Color("#a8b7b3")
const GOLD: Color = Color("#e6ad5b")
const TEAL: Color = Color("#5ed0bd")
const RED: Color = Color("#db695f")
const TEAM_HUD_SCRIPT: Script = preload("res://features/ui/team_hud.gd")

var _world: GameWorld
var _status: Label
var _stats: Label
var _health_bar: ProgressBar
var _xp_bar: ProgressBar
var _ultimate_bar: ProgressBar
var _ultimate_label: Label
var _boss_panel: PanelContainer
var _boss_health_bar: ProgressBar
var _upgrade_panel: PanelContainer
var _upgrade_title: Label
var _upgrade_buttons: Array[Button] = []
var _game_over_shade: ColorRect
var _game_over_label: Label
var _game_over_summary: Label
var _game_over_button: Button
var _game_over_retry: Button
var _chest_panel: PanelContainer
var _chest_title: Label
var _chest_buttons: Array[Button] = []
var _chest_choice_ids: PackedInt32Array = PackedInt32Array()
var _active_chest_id: int = -1
var _pause_overlay: ColorRect
var _master_volume: HSlider
var _paused: bool = false

func _ready() -> void:
	if NetworkManager.is_dedicated_mode():
		queue_free()
		return
	_world = get_parent() as GameWorld
	_build_ui()
	var objective_manager: ObjectiveManager = _world.get_node("ObjectiveManager") as ObjectiveManager
	objective_manager.chest_choice_requested.connect(_on_chest_choice_requested)
	objective_manager.chest_choice_closed.connect(_on_chest_choice_closed)

func _process(_delta: float) -> void:
	if not is_instance_valid(_world):
		return
	var objective: String = "SOBREVIVE HASTA LA CRIATURA ALFA · 05:00"
	if _world.is_boss_active():
		objective = "DERROTA A LA CRIATURA ALFA"
	elif _world.objective_manager.active_event_kind >= 0:
		objective = _world.objective_manager.get_event_kind_name()
	elif _world.elapsed_seconds >= 270.0:
		objective = "EL PORTAL SE ESTÁ ABRIENDO"
	_status.text = "%02d:%02d   ·   %d CRIATURAS   ·   %s\n%s" % [floori(_world.elapsed_seconds / 60.0), floori(fmod(_world.elapsed_seconds, 60.0)), _world.alive_enemy_count, "ANFITRIÓN" if multiplayer.is_server() else "ALIADO", objective]
	var ended: bool = _world.game_over
	if ended and _paused:
		_set_paused(false)
	_game_over_shade.visible = ended
	_game_over_label.visible = ended
	_game_over_summary.visible = ended
	_game_over_button.visible = ended
	_game_over_retry.visible = ended
	_boss_panel.visible = _world.is_boss_active() and not ended
	_boss_health_bar.value = _world.get_boss_health_ratio() * 100.0
	if _world.run_result == &"victory":
		_game_over_label.text = "EXPEDICIÓN COMPLETADA"
	else:
		_game_over_label.text = "EXPEDICIÓN FALLIDA"
	_game_over_summary.text = "%s\n\nDURACIÓN   %02d:%02d\nCRIATURAS ELIMINADAS   %d\nNIVEL DEL ESCUADRÓN   %d\nRECOMPENSA   +%d ORO" % ["La incursión estabilizó el portal y despejó la zona." if _world.run_result == &"victory" else "La horda tomó la zona. Reúne al escuadrón e inténtalo otra vez.", floori(_world.elapsed_seconds / 60.0), floori(fmod(_world.elapsed_seconds, 60.0)), _world.run_kills, _world.team_level, _world.run_reward]
	var player: Player = _world.get_local_player()
	if player == null:
		_stats.text = "Buscando señal del escuadrón…"
		_upgrade_panel.visible = false
		return
	if player.replicated_downed:
		var reviver_text: String = "BUSCANDO ALIADO" if player.replicated_reviver_peer_id < 0 else "ALIADO %d REANIMANDO" % player.replicated_reviver_peer_id
		_stats.text = "ABATIDO · SANGRADO %.0f s · %s · %d%%" % [player.replicated_bleedout_left, reviver_text, roundi(player.replicated_revive_progress * 100.0)]
	elif player.replicated_dead:
		if player.replicated_respawn_at >= _world.elapsed_seconds:
			_stats.text = "CAÍDO · REGRESAS EN LA SIGUIENTE OLEADA · %.0f s" % (player.replicated_respawn_at - _world.elapsed_seconds)
		else:
			_stats.text = "CAÍDO · LA ZONA DE EXTRACCIÓN YA SE PERDIÓ"
	else:
		var weapon_status: String = player.get_weapon_evolution_name() if player.replicated_weapon_evolved else "PULSO %d/5 · DARDOS %d · HOJAS %d" % [player.replicated_weapon_level, player.replicated_dart_level, player.replicated_blade_level]
		var buff_status: String = ""
		if player.replicated_team_buff_left > 0.0:
			buff_status = " · BENDICIÓN %ds" % ceili(player.replicated_team_buff_left)
		var access_cards: int = _world.objective_manager.team_access_cards
		_stats.text = "NIVEL %02d   ·   VIDA %03.0f/%03.0f   ·   XP %d/%d\n%s%s   ·   TARJETAS %d" % [player.replicated_level, player.replicated_health, player.replicated_max_health, player.replicated_xp, player.replicated_xp_to_next, weapon_status, buff_status, access_cards]
	_health_bar.max_value = maxf(1.0, player.replicated_max_health)
	_health_bar.value = player.replicated_health
	_xp_bar.max_value = maxf(1.0, player.replicated_xp_to_next)
	_xp_bar.value = player.replicated_xp
	var ultimate_cooldown: float = player.get_ultimate_cooldown()
	_ultimate_bar.max_value = maxf(1.0, ultimate_cooldown)
	_ultimate_bar.value = maxf(0.0, ultimate_cooldown - player.replicated_ultimate_cooldown_left)
	_ultimate_label.text = "R  ·  %s  ·  %s" % [player.get_ultimate_name(), "LISTA" if player.replicated_ultimate_cooldown_left <= 0.0 else "%.0f s" % player.replicated_ultimate_cooldown_left]
	_upgrade_panel.visible = player.replicated_upgrade_tokens > 0 and player.replicated_health > 0.0 and not ended and not _chest_panel.visible
	_upgrade_title.text = "ELIGE TU BENDICIÓN   ·   %d DISPONIBLE" % player.replicated_upgrade_tokens
	for index: int in range(_upgrade_buttons.size()):
		var has_choice: bool = index < player.replicated_upgrade_choices.size()
		_upgrade_buttons[index].visible = has_choice
		if has_choice:
			var choice_id: int = player.replicated_upgrade_choices[index]
			_upgrade_buttons[index].text = BlessingCatalog.display_text(choice_id)
			_upgrade_buttons[index].icon = load(BlessingCatalog.icon_path(choice_id)) as Texture2D

func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var team_hud: Control = Control.new()
	team_hud.set_script(TEAM_HUD_SCRIPT)
	team_hud.set("world", _world)
	root.add_child(team_hud)
	var top_panel: PanelContainer = PanelContainer.new()
	top_panel.position = Vector2(22.0, 18.0)
	top_panel.custom_minimum_size = Vector2(490.0, 138.0)
	top_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, EDGE, 8, 1))
	root.add_child(top_panel)
	var info: VBoxContainer = VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	top_panel.add_child(info)
	var header: HBoxContainer = HBoxContainer.new()
	info.add_child(header)
	var crest: Label = _label("✦", 19, GOLD)
	header.add_child(crest)
	_status = _label("00:00   ·   0 CRIATURAS   ·   ANFITRIÓN\nSOBREVIVE HASTA EL GUARDIÁN · 05:00", 12, PAPER)
	_status.add_theme_constant_override("line_spacing", 3)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_status)
	var health_row: HBoxContainer = HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	info.add_child(health_row)
	health_row.add_child(_label("VIDA", 10, RED))
	_health_bar = _bar(13.0, RED)
	health_row.add_child(_health_bar)
	var xp_row: HBoxContainer = HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	info.add_child(xp_row)
	xp_row.add_child(_label("ÉTER", 10, TEAL))
	_xp_bar = _bar(8.0, TEAL)
	xp_row.add_child(_xp_bar)
	var ultimate_row: HBoxContainer = HBoxContainer.new()
	ultimate_row.add_theme_constant_override("separation", 8)
	info.add_child(ultimate_row)
	_ultimate_label = _label("R  ·  DEFINITIVA  ·  LISTA", 10, GOLD)
	_ultimate_label.custom_minimum_size.x = 190.0
	ultimate_row.add_child(_ultimate_label)
	_ultimate_bar = _bar(8.0, GOLD)
	ultimate_row.add_child(_ultimate_bar)
	_stats = _label("Conectando al escuadrón…", 10, MUTED)
	info.add_child(_stats)

	_boss_panel = PanelContainer.new()
	_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position = Vector2(-230.0, 20.0)
	_boss_panel.custom_minimum_size = Vector2(460.0, 65.0)
	_boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.045, 0.035, 0.94), Color("#b3654b"), 7, 2))
	_boss_panel.visible = false
	root.add_child(_boss_panel)
	var boss_column: VBoxContainer = VBoxContainer.new()
	boss_column.add_theme_constant_override("separation", 4)
	_boss_panel.add_child(boss_column)
	var boss_title: Label = _label("✦   GUARDIÁN DE LA CRIPTA   ✦", 12, Color("#f3c28c"))
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_column.add_child(boss_title)
	_boss_health_bar = _bar(14.0, Color("#d25d51"))
	_boss_health_bar.max_value = 100.0
	_boss_health_bar.value = 100.0
	boss_column.add_child(_boss_health_bar)

	_upgrade_panel = PanelContainer.new()
	_upgrade_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_upgrade_panel.position = Vector2(-370.0, -208.0)
	_upgrade_panel.custom_minimum_size = Vector2(740.0, 190.0)
	_upgrade_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.075, 0.08, 0.97), Color("#79c4af"), 8, 3))
	_upgrade_panel.visible = false
	root.add_child(_upgrade_panel)
	var upgrade_column: VBoxContainer = VBoxContainer.new()
	upgrade_column.add_theme_constant_override("separation", 8)
	_upgrade_panel.add_child(upgrade_column)
	_upgrade_title = _label("ELIGE UNA BENDICIÓN", 12, GOLD)
	_upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_column.add_child(_upgrade_title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	upgrade_column.add_child(row)
	for index: int in range(3):
		var button: Button = _button("MEJORA", index)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 104.0)
		button.add_theme_font_size_override("font_size", 10)
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_upgrade_pressed.bind(index))
		row.add_child(button)
		_upgrade_buttons.append(button)
	_build_chest_ui(root)
	_build_pause_ui(root)

	_game_over_shade = ColorRect.new()
	_game_over_shade.color = Color(0.015, 0.025, 0.03, 0.72)
	_game_over_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_over_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_shade.visible = false
	root.add_child(_game_over_shade)
	var end_panel: PanelContainer = PanelContainer.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	end_panel.position = Vector2(-290.0, -205.0)
	end_panel.custom_minimum_size = Vector2(580.0, 410.0)
	end_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.065, 0.075, 0.98), GOLD, 10, 6))
	_game_over_shade.add_child(end_panel)
	var end_column: VBoxContainer = VBoxContainer.new()
	end_column.alignment = BoxContainer.ALIGNMENT_CENTER
	end_column.add_theme_constant_override("separation", 12)
	end_panel.add_child(end_column)
	_game_over_label = _label("ZONA DE INCURSIÓN PERDIDA", 24, PAPER)
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_column.add_child(_game_over_label)
	_game_over_summary = _label("La expedición terminó.", 12, MUTED)
	_game_over_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_summary.add_theme_constant_override("line_spacing", 4)
	end_column.add_child(_game_over_summary)
	_game_over_retry = _button("JUGAR OTRA VEZ", 1)
	_game_over_retry.custom_minimum_size.y = 46.0
	_game_over_retry.pressed.connect(NetworkManager.restart_run)
	end_column.add_child(_game_over_retry)
	_game_over_button = _button("VOLVER AL REFUGIO", 0)
	_game_over_button.custom_minimum_size.y = 42.0
	_game_over_button.pressed.connect(NetworkManager.leave_session)
	end_column.add_child(_game_over_button)

func _build_pause_ui(root: Control) -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0.012, 0.02, 0.025, 0.78)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.visible = false
	_pause_overlay.z_index = 20
	root.add_child(_pause_overlay)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220.0, -170.0)
	panel.custom_minimum_size = Vector2(440.0, 340.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#101d24"), GOLD, 10, 10))
	_pause_overlay.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title: Label = _label("PAUSA LOCAL", 24, PAPER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note: Label = _label("La expedición sigue para el escuadrón.\nTu personaje se queda quieto.", 13, MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var volume_label: Label = _label("VOLUMEN GENERAL", 11, GOLD)
	column.add_child(volume_label)
	_master_volume = HSlider.new()
	_master_volume.min_value = 0.0
	_master_volume.max_value = 1.0
	_master_volume.step = 0.01
	_master_volume.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	_master_volume.value_changed.connect(_on_master_volume_changed)
	column.add_child(_master_volume)
	var resume: Button = _button("CONTINUAR  ·  ESC", 1)
	resume.custom_minimum_size.y = 44.0
	resume.pressed.connect(toggle_pause)
	column.add_child(resume)
	var leave: Button = _button("ABANDONAR EXPEDICIÓN", 0)
	leave.custom_minimum_size.y = 42.0
	leave.pressed.connect(NetworkManager.leave_session)
	column.add_child(leave)

func toggle_pause() -> void:
	if not is_instance_valid(_world) or _world.game_over:
		return
	_set_paused(not _paused)

func _set_paused(paused: bool) -> void:
	_paused = paused
	_pause_overlay.visible = paused
	NetworkManager.set_local_game_paused(paused)
	var player: Player = _world.get_local_player() if is_instance_valid(_world) else null
	if player != null:
		player.set_local_paused(paused)
	if paused:
		_chest_panel.visible = false if _active_chest_id < 0 else _chest_panel.visible

func _on_master_volume_changed(value: float) -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value, 0.0001)))

func _build_chest_ui(root: Control) -> void:
	_chest_panel = PanelContainer.new()
	_chest_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_chest_panel.position = Vector2(-270.0, -165.0)
	_chest_panel.custom_minimum_size = Vector2(540.0, 122.0)
	_chest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.055, 0.035, 0.97), GOLD, 8, 4))
	_chest_panel.visible = false
	root.add_child(_chest_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_chest_panel.add_child(column)
	_chest_title = _label("SUMINISTROS DE CAMPO", 12, GOLD)
	_chest_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_chest_title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for index: int in range(3):
		var button: Button = _button("Mejora", index)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 52.0
		button.pressed.connect(_on_chest_choice_pressed.bind(index))
		row.add_child(button)
		_chest_buttons.append(button)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _bar(height: float, fill: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color("#172226")
	background.set_corner_radius_all(3)
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar

func _button(text: String, index: int) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var edge: Color = GOLD if index == 0 else TEAL
	button.add_theme_stylebox_override("normal", _panel_style(Color("#15272b"), edge.darkened(0.45), 6, 0))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#263b3d"), edge, 6, 0))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#0d191d"), edge, 6, 0))
	return button

func _panel_style(fill: Color, edge: Color, radius: int, shadow: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = shadow
	style.content_margin_left = 13.0
	style.content_margin_right = 13.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style

func _on_upgrade_pressed(choice: int) -> void:
	var player: Player = _world.get_local_player() if is_instance_valid(_world) else null
	if player != null and choice >= 0 and choice < player.replicated_upgrade_choices.size():
		player.request_upgrade(player.replicated_upgrade_choices[choice])

func _on_chest_choice_requested(peer_id: int, chest_id: int, choices: PackedInt32Array) -> void:
	if peer_id != multiplayer.get_unique_id() or choices.size() != 3:
		return
	_active_chest_id = chest_id
	_chest_choice_ids = choices
	_chest_title.text = "COFRE DE ORO · ELIGE UNA RECOMPENSA" if _world.objective_manager.is_golden_chest(chest_id) else "TARJETA DE ACCESO · ELIGE UNA RECOMPENSA"
	for index: int in range(_chest_buttons.size()):
		var option_id: int = choices[index]
		_chest_buttons[index].text = EquipmentCatalog.choice_name(option_id) if EquipmentCatalog.is_equipment_choice(option_id) else ["ARMA +1 NIVEL", "PASIVA DE CADENCIA", "VIDA MÁXIMA +28", "DAÑO +22%", "REDUCIR DEFINITIVA"][clampi(option_id, 0, 4)]
	_chest_panel.visible = true
	_upgrade_panel.visible = false

func _on_chest_choice_pressed(index: int) -> void:
	if _active_chest_id < 0 or index < 0 or index >= _chest_choice_ids.size():
		return
	_world.objective_manager.choose_chest(_active_chest_id, _chest_choice_ids[index])

func _on_chest_choice_closed(chest_id: int) -> void:
	if chest_id != _active_chest_id:
		return
	_active_chest_id = -1
	_chest_choice_ids.clear()
	_chest_panel.visible = false
