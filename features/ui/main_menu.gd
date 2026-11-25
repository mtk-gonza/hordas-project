extends Control

const MENU_BACKGROUND: String = "res://art/processed/neon_city_arena.png"
const PANEL_COLOR: Color = Color(0.025, 0.055, 0.075, 0.94)
const PANEL_EDGE: Color = Color("#70818a")
const TEXT_MAIN: Color = Color("#f4e7ce")
const TEXT_MUTED: Color = Color("#aab8b8")
const GOLD: Color = Color("#e4aa57")
const TEAL: Color = Color("#58c1b8")

var _status_label: Label
var _players_label: Label
var _start_button: Button
var _host_port: SpinBox
var _address: LineEdit
var _join_port: SpinBox
var _slot_labels: Array[Label] = []
var _meta_panel: PanelContainer
var _meta_gold_label: Label
var _meta_upgrade_labels: Array[Label] = []
var _meta_upgrade_buttons: Array[Button] = []
const META_UPGRADE_IDS: Array[String] = ["damage", "health", "speed", "duration"]
const META_UPGRADE_NAMES: Array[String] = ["Daño global", "Salud máxima", "Velocidad", "Duración definitiva"]
const CHARACTER_LABELS: Array[String] = ["GUARDIÁN · RÁFAGA SOLAR", "INVOCADORA · TORMENTA", "CUSTODIA LUNAR · CAÍDA LUNAR", "GUARDIANA DEL BOSQUE · PULSO VERDE"]
const CHARACTER_IDS: Array[StringName] = [&"warden", &"stormcaller", &"moonkeeper", &"grovekeeper"]
var _character_select: OptionButton
var _map_select: OptionButton

func _ready() -> void:
	if NetworkManager.is_dedicated_mode():
		return
	_build_ui()
	_build_meta_ui()
	NetworkManager.status_changed.connect(_on_status_changed)
	NetworkManager.lobby_changed.connect(_refresh_lobby)
	MetaProgression.profile_changed.connect(_refresh_meta_ui)
	_refresh_lobby()
	_on_status_changed("Preparado para descender.")

func _build_ui() -> void:
	var background: TextureRect = TextureRect.new()
	background.texture = load(MENU_BACKGROUND) as Texture2D
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var wash: ColorRect = ColorRect.new()
	wash.color = Color(0.012, 0.028, 0.04, 0.3)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(510.0, 660.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL_COLOR, PANEL_EDGE, 12, 18))
	row.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var kicker: Label = _label("COOPERATIVO · 1–4 JUGADORES", 13, TEAL)
	kicker.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	kicker.add_theme_constant_override("outline_size", 3)
	column.add_child(kicker)
	var title: Label = _label("HORDAS", 58, TEXT_MAIN)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 4)
	column.add_child(title)
	column.add_child(_label("INCURSIÓN NEÓN", 17, GOLD))
	column.add_child(_label("Contén la invasión, purga los núcleos y escolta el dron.\nAl minuto cinco, derrota a la criatura alfa.", 15, TEXT_MUTED))
	var character_row: HBoxContainer = HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 12)
	column.add_child(character_row)
	character_row.add_child(_label("CAMPEÓN", 12, GOLD))
	_character_select = OptionButton.new()
	_character_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_select.custom_minimum_size.y = 36.0
	_character_select.add_theme_color_override("font_color", TEXT_MAIN)
	_character_select.add_theme_stylebox_override("normal", _panel_style(Color("#101d24"), Color("#455860"), 5, 0))
	for index: int in range(CHARACTER_IDS.size()):
		_character_select.add_item(CHARACTER_LABELS[index], index)
	var selected_character_index: int = CHARACTER_IDS.find(NetworkManager.get_local_character_id())
	_character_select.select(maxi(0, selected_character_index))
	_character_select.item_selected.connect(_on_character_selected)
	character_row.add_child(_character_select)
	character_row.add_child(_label("MAPA", 11, GOLD))
	_map_select = OptionButton.new()
	_map_select.custom_minimum_size.x = 190.0
	_map_select.custom_minimum_size.y = 36.0
	_map_select.add_theme_color_override("font_color", TEXT_MAIN)
	_map_select.add_theme_stylebox_override("normal", _panel_style(Color("#101d24"), Color("#455860"), 5, 0))
	for map_id: StringName in GameMapCatalog.all_ids():
		_map_select.add_item(GameMapCatalog.display_name(map_id))
	_map_select.select(GameMapCatalog.index_for(NetworkManager.selected_map_id))
	_map_select.tooltip_text = GameMapCatalog.rule_summary(NetworkManager.selected_map_id)
	_map_select.item_selected.connect(_on_map_selected)
	character_row.add_child(_map_select)
	column.add_child(_separator())

	column.add_child(_label("CREAR ESCUADRÓN", 13, GOLD))
	var host_row: HBoxContainer = HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 8)
	column.add_child(host_row)
	_host_port = _make_port_field(NetworkManager.DEFAULT_PORT)
	_host_port.custom_minimum_size.x = 108.0
	host_row.add_child(_labeled_control("PUERTO", _host_port))
	var host_button: Button = _make_button("Crear sala", true)
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_button.pressed.connect(_host_pressed)
	host_row.add_child(host_button)

	column.add_child(_label("UNIRSE A UN ESCUADRÓN", 13, GOLD))
	_address = LineEdit.new()
	_address.placeholder_text = "IP del host · ej. 192.168.1.20"
	_address.text = "127.0.0.1"
	_address.custom_minimum_size.y = 40.0
	_address.add_theme_color_override("font_color", TEXT_MAIN)
	_address.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	_address.add_theme_stylebox_override("normal", _panel_style(Color("#101d24"), Color("#455860"), 5, 0))
	_address.add_theme_stylebox_override("focus", _panel_style(Color("#101d24"), GOLD, 5, 0))
	column.add_child(_address)
	var join_row: HBoxContainer = HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	column.add_child(join_row)
	_join_port = _make_port_field(NetworkManager.DEFAULT_PORT)
	_join_port.custom_minimum_size = Vector2(116.0, 40.0)
	join_row.add_child(_labeled_control("PUERTO UDP", _join_port))
	var join_button: Button = _make_button("Conectar", false)
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(_join_pressed)
	join_row.add_child(join_button)

	column.add_child(_separator())
	var lobby_row: HBoxContainer = HBoxContainer.new()
	_players_label = _label("ESCUADRÓN · 0 / 4", 14, TEXT_MAIN)
	_players_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lobby_row.add_child(_players_label)
	column.add_child(lobby_row)
	var slots: HBoxContainer = HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	column.add_child(slots)
	for index: int in range(4):
		var slot: PanelContainer = PanelContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = 46.0
		slot.add_theme_stylebox_override("panel", _panel_style(Color("#0b171e"), Color("#34464d"), 6, 0))
		var slot_label: Label = _label("VACÍO", 11, Color("#718187"))
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(slot_label)
		slots.add_child(slot)
		_slot_labels.append(slot_label)
	_start_button = _make_button("Iniciar expedición", true)
	_start_button.custom_minimum_size.y = 46.0
	_start_button.pressed.connect(_start_pressed)
	column.add_child(_start_button)
	_status_label = _label("Preparado para descender.", 13, TEXT_MUTED)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.y = 34.0
	column.add_child(_status_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var controls: Label = _label("WASD / FLECHAS / STICK IZQ.  ·  MOVER\nESPACIO / A  ·  ATAQUE MANUAL\nE / B  ·  HABILIDAD DE ÁREA\nF / X  ·  INTERACTUAR\nR / Y  ·  DEFINITIVA\nESC / START  ·  PAUSA LOCAL", 13, Color(0.88, 0.9, 0.84, 0.78))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	controls.size_flags_vertical = Control.SIZE_SHRINK_END
	controls.add_theme_constant_override("line_spacing", 5)
	row.add_child(controls)

func _build_meta_ui() -> void:
	var toggle: Button = _make_button("LEGADO", false)
	toggle.position = Vector2(1090.0, 22.0)
	toggle.size = Vector2(150.0, 42.0)
	toggle.pressed.connect(_toggle_meta_panel)
	add_child(toggle)
	_meta_panel = PanelContainer.new()
	_meta_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_meta_panel.position = Vector2(-250.0, -235.0)
	_meta_panel.custom_minimum_size = Vector2(500.0, 470.0)
	_meta_panel.add_theme_stylebox_override("panel", _panel_style(PANEL_COLOR, GOLD, 10, 8))
	_meta_panel.visible = false
	add_child(_meta_panel)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_meta_panel.add_child(column)
	column.add_child(_label("LEGADO DE LA ESCUADRA", 24, TEXT_MAIN))
	column.add_child(_label("Invierte el oro de las expediciones en mejoras permanentes.", 13, TEXT_MUTED))
	_meta_gold_label = _label("ORO · 0", 18, GOLD)
	column.add_child(_meta_gold_label)
	for index: int in range(META_UPGRADE_IDS.size()):
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		column.add_child(row)
		var item: VBoxContainer = VBoxContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(_label(META_UPGRADE_NAMES[index], 14, TEXT_MAIN))
		var info: Label = _label("Nivel 0 / 10", 11, TEXT_MUTED)
		item.add_child(info)
		_meta_upgrade_labels.append(info)
		row.add_child(item)
		var buy: Button = _make_button("Mejorar", true)
		buy.custom_minimum_size.x = 112.0
		buy.pressed.connect(_buy_meta_upgrade.bind(index))
		row.add_child(buy)
		_meta_upgrade_buttons.append(buy)
	var close: Button = _make_button("Volver", false)
	close.pressed.connect(_toggle_meta_panel)
	column.add_child(close)
	_refresh_meta_ui()

func _toggle_meta_panel() -> void:
	_meta_panel.visible = not _meta_panel.visible
	_refresh_meta_ui()

func _buy_meta_upgrade(index: int) -> void:
	if index < 0 or index >= META_UPGRADE_IDS.size():
		return
	MetaProgression.purchase(META_UPGRADE_IDS[index])

func _on_character_selected(index: int) -> void:
	if index < 0 or index >= CHARACTER_IDS.size():
		return
	NetworkManager.set_local_character_id(CHARACTER_IDS[index])

func _on_map_selected(index: int) -> void:
	var map_id: StringName = GameMapCatalog.id_at(index)
	NetworkManager.set_selected_map_id(map_id)
	_map_select.tooltip_text = GameMapCatalog.rule_summary(map_id)

func _refresh_meta_ui() -> void:
	if not is_instance_valid(_meta_gold_label):
		return
	_meta_gold_label.text = "ORO · %d" % MetaProgression.gold
	for index: int in range(META_UPGRADE_IDS.size()):
		var upgrade_id: String = META_UPGRADE_IDS[index]
		var level: int = MetaProgression.get_upgrade_level(upgrade_id)
		var cost: int = MetaProgression.cost_for(upgrade_id)
		_meta_upgrade_labels[index].text = "Nivel %d / 10  ·  Coste %d" % [level, cost]
		_meta_upgrade_buttons[index].disabled = level >= 10 or MetaProgression.gold < cost

func _label(text: String, font_size: int, color: Color) -> Label:
	var result: Label = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

func _separator() -> HSeparator:
	var separator: HSeparator = HSeparator.new()
	separator.add_theme_color_override("color", Color(0.76, 0.57, 0.33, 0.55))
	return separator

func _make_button(text: String, is_primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 40.0
	button.add_theme_font_size_override("font_size", 15)
	var normal: Color = Color("#a96c36") if is_primary else Color("#1d3740")
	var hover: Color = Color("#c48748") if is_primary else Color("#2b4c54")
	button.add_theme_color_override("font_color", Color("#fff1d7"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(normal, Color("#84582f") if is_primary else Color("#455860"), 6, 0))
	button.add_theme_stylebox_override("hover", _panel_style(hover, Color("#ffe0a1"), 6, 0))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#70452d"), Color("#e4b36e"), 6, 0))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("#283237"), Color("#3a474a"), 6, 0))
	return button

func _panel_style(fill: Color, edge: Color, radius: int, shadow: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = shadow
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 13.0
	return style

func _make_port_field(default_value: int) -> SpinBox:
	var field: SpinBox = SpinBox.new()
	field.min_value = 1
	field.max_value = 65535
	field.step = 1
	field.value = default_value
	field.custom_minimum_size.y = 40.0
	return field

func _labeled_control(label_text: String, control: Control) -> VBoxContainer:
	var group: VBoxContainer = VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	var caption: Label = _label(label_text, 10, TEXT_MUTED)
	group.add_child(caption)
	group.add_child(control)
	return group

func _host_pressed() -> void:
	var result: Error = NetworkManager.host_game(int(_host_port.value))
	if result != OK:
		_on_status_changed("No se pudo abrir el puerto UDP %d." % int(_host_port.value))

func _join_pressed() -> void:
	var result: Error = NetworkManager.join_game(_address.text, int(_join_port.value))
	if result != OK:
		_on_status_changed("Revisa la dirección y el puerto UDP.")

func _start_pressed() -> void:
	NetworkManager.start_run()

func _refresh_lobby() -> void:
	if not is_instance_valid(_players_label):
		return
	var ids: Array[int] = NetworkManager.get_player_ids()
	_players_label.text = "ESCUADRÓN · %d / 4" % ids.size()
	for index: int in range(_slot_labels.size()):
		var label: Label = _slot_labels[index]
		if index < ids.size():
			label.text = "ANFITRIÓN" if ids[index] == 1 else "JUGADOR %d" % (index + 1)
			label.add_theme_color_override("font_color", GOLD if ids[index] == 1 else TEAL)
		else:
			label.text = "VACÍO"
			label.add_theme_color_override("font_color", Color("#718187"))
	_start_button.visible = NetworkManager.is_session_host()
	_start_button.disabled = ids.is_empty()
	if is_instance_valid(_map_select):
		_map_select.select(GameMapCatalog.index_for(NetworkManager.selected_map_id))
		_map_select.tooltip_text = GameMapCatalog.rule_summary(NetworkManager.selected_map_id)
		_map_select.disabled = multiplayer.multiplayer_peer is ENetMultiplayerPeer and not NetworkManager.is_session_host()

func _on_status_changed(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
