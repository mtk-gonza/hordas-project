extends Node2D
class_name EnemyVisual

const ASSET_ROOT: String = "res://art/external/pixel_crawler/game/enemies/"
const CREATURE_ROOT: String = "res://art/external/creatures/"
const BOSS_ROOT: String = "res://art/external/bosses/"
const BOSS_FRAME_SIZES: Dictionary = {&"elder_treant": 64, &"gel_monarch": 48, &"dragon_whelp": 48, &"bone_archmage": 48, &"tide_kraken": 64, &"golem_king": 64}
const MOVE_START_DISTANCE_SQUARED: float = 0.04
const IDLE_GRACE_SECONDS: float = 0.22

@export var is_boss: bool = false
@export var is_miniboss: bool = false
static var _frames_by_kind: Dictionary = {}
var archetype: StringName = &"base"
var visual_species: StringName = &""
var _radius: float = 17.0
var _color: Color = Color("#d86456")
var _animated_sprite: AnimatedSprite2D
var _previous_position: Vector2 = Vector2.ZERO
var _last_animation: StringName = &""
var _stationary_time: float = IDLE_GRACE_SECONDS
var _is_dead: bool = false
var _dedicated_mode: bool = false
var _hit_flash_left: float = 0.0
var _boss_telegraph_left: float = 0.0
var _boss_telegraph_duration: float = 1.0
var _boss_telegraph_center: Vector2 = Vector2.ZERO
var _boss_telegraph_radius: float = 0.0
var _boss_slam_left: float = 0.0
var _elite_modifier: int = 0
var _enraged: bool = false
var _visual_refresh_left: float = 0.0
var _mage_telegraph_left: float = 0.0
var _mage_bolt_left: float = 0.0
var _mage_attack_target: Vector2 = Vector2.ZERO
var _using_asset_creature: bool = false
var _using_asset_boss: bool = false
var _boss_phase_two: bool = false
var _action_animation_left: float = 0.0
var _last_direction: StringName = &"down"

func _ready() -> void:
	if NetworkManager.is_dedicated_mode():
		_dedicated_mode = true
		set_process(false)
		return
	var enemy: BaseEnemy = get_parent() as BaseEnemy
	if enemy != null:
		is_boss = enemy.is_boss
		is_miniboss = enemy.is_miniboss
		archetype = enemy.archetype
		visual_species = enemy.visual_species
		_elite_modifier = enemy.elite_modifier
	_animated_sprite = AnimatedSprite2D.new()
	_animated_sprite.name = "Sprite"
	_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if is_boss and BOSS_FRAME_SIZES.has(visual_species):
		_animated_sprite.sprite_frames = _build_external_boss_frames()
		_using_asset_boss = true
	else:
		_animated_sprite.sprite_frames = _build_external_sprite_frames() if not is_boss and not visual_species.is_empty() else null
	_using_asset_creature = not _using_asset_boss and _animated_sprite.sprite_frames != null
	if not _using_asset_creature:
		_animated_sprite.sprite_frames = _build_sprite_frames()
	var visual_scale: float = 1.85
	if is_boss:
		visual_scale = 2.5 if _using_asset_boss else 2.8
	elif is_miniboss:
		visual_scale = 3.0 if _using_asset_creature else 2.2
	elif _using_asset_creature:
		visual_scale = 2.15
	elif archetype == &"plague_brute":
		visual_scale = 2.1
	_animated_sprite.scale = Vector2.ONE * visual_scale
	if _using_asset_creature:
		_animated_sprite.offset.y = -8.0
	elif _using_asset_boss:
		_animated_sprite.offset.y = -float(BOSS_FRAME_SIZES[visual_species]) * 0.5
	add_child(_animated_sprite)
	_previous_position = get_parent().global_position
	if _using_asset_creature or _using_asset_boss:
		_color = Color.WHITE
	elif is_boss:
		_radius = 38.0
		_color = Color("#dc754d")
	elif is_miniboss:
		_radius = 25.0
		_color = Color("#e1a753")
	else:
		if archetype == &"warrior":
			_color = Color("#7ba9bd")
		elif archetype == &"rogue":
			_color = Color("#9b8060")
		elif archetype == &"mage":
			_color = Color("#ad78c7")
		elif archetype == &"soul_weaver":
			_color = Color("#bd8be8")
		elif archetype == &"storm_mage":
			_color = Color("#85d8e5")
		elif archetype == &"bone_archer":
			_color = Color("#d6c878")
		elif archetype == &"plague_brute":
			_color = Color("#89ad65")
		else:
			_color = Color("#d6ccb7")
	var initial_animation: StringName = &"idle_down" if _using_asset_creature else &"idle"
	if _animated_sprite.sprite_frames != null and _animated_sprite.sprite_frames.has_animation(initial_animation):
		_animated_sprite.play(initial_animation)
		_last_animation = initial_animation
	if _using_asset_boss and _animated_sprite.sprite_frames.has_animation(&"intro_roar"):
		_action_animation_left = 0.6
		_play_asset_action(&"intro_roar")
	queue_redraw()

func _process(delta: float) -> void:
	if _is_dead:
		return
	_boss_telegraph_left = maxf(0.0, _boss_telegraph_left - delta)
	_boss_slam_left = maxf(0.0, _boss_slam_left - delta)
	_mage_telegraph_left = maxf(0.0, _mage_telegraph_left - delta)
	_mage_bolt_left = maxf(0.0, _mage_bolt_left - delta)
	_hit_flash_left = maxf(0.0, _hit_flash_left - delta)
	_action_animation_left = maxf(0.0, _action_animation_left - delta)
	_visual_refresh_left -= delta
	_animated_sprite.modulate = Color(1.0, 0.78, 0.58, 1.0) if _hit_flash_left > 0.0 else _color
	var body: Node2D = get_parent() as Node2D
	if body == null:
		return
	if _using_asset_boss:
		var boss: BaseEnemy = body as BaseEnemy
		if boss != null and not _boss_phase_two and boss.health <= boss.max_health * 0.5:
			_boss_phase_two = true
			_last_animation = &""
	var movement: Vector2 = body.global_position - _previous_position
	_previous_position = body.global_position
	if movement.length_squared() > MOVE_START_DISTANCE_SQUARED:
		_stationary_time = 0.0
		if absf(movement.x) > absf(movement.y):
			_last_direction = &"right" if movement.x > 0.0 else &"left"
		elif absf(movement.y) > 0.02:
			_last_direction = &"down" if movement.y > 0.0 else &"up"
	else:
		_stationary_time += delta
	if _action_animation_left <= 0.0:
		var locomotion: String = "walk" if _stationary_time < IDLE_GRACE_SECONDS else "idle"
		var animation: StringName = StringName("%s_%s" % [locomotion, _last_direction]) if _using_asset_creature else StringName("run" if locomotion == "walk" and not _using_asset_boss else ("walk" if locomotion == "walk" else "idle"))
		if _using_asset_boss and _boss_phase_two and _animated_sprite.sprite_frames.has_animation(StringName("p2_%s" % animation)):
			animation = StringName("p2_%s" % animation)
		if animation != _last_animation and _animated_sprite.sprite_frames.has_animation(animation):
			_animated_sprite.play(animation)
			_last_animation = animation
	if _visual_refresh_left <= 0.0:
		_visual_refresh_left = 0.08
		queue_redraw()

func set_elite_modifier(modifier: int) -> void:
	_elite_modifier = modifier
	queue_redraw()

func set_enraged(enabled: bool) -> void:
	_enraged = enabled
	queue_redraw()

func show_elite_burst(origin: Vector2, radius: float) -> void:
	_boss_telegraph_center = origin
	_boss_telegraph_radius = radius
	_boss_slam_left = 0.42
	queue_redraw()

func show_boss_telegraph(center: Vector2, radius: float, duration: float) -> void:
	_boss_telegraph_center = center
	_boss_telegraph_radius = maxf(1.0, radius)
	_boss_telegraph_duration = maxf(0.1, duration)
	_boss_telegraph_left = _boss_telegraph_duration
	queue_redraw()

func show_boss_slam(center: Vector2, radius: float) -> void:
	_boss_telegraph_left = 0.0
	_boss_telegraph_center = center
	_boss_telegraph_radius = maxf(1.0, radius)
	_boss_slam_left = 0.34
	queue_redraw()

func show_mage_telegraph(target: Vector2) -> void:
	_mage_attack_target = target
	_mage_telegraph_left = 0.82
	queue_redraw()

func show_mage_bolt(target: Vector2) -> void:
	_mage_attack_target = target
	_mage_telegraph_left = 0.0
	_mage_bolt_left = 0.2
	queue_redraw()

func play_death() -> void:
	_is_dead = true
	if not is_instance_valid(_animated_sprite):
		return
	var animation: StringName = StringName("death_%s" % _last_direction) if _using_asset_creature else &"death"
	if _animated_sprite.sprite_frames.has_animation(animation):
		_animated_sprite.play(animation)
		_last_animation = animation

func play_attack() -> void:
	if not (_using_asset_creature or _using_asset_boss) or not is_instance_valid(_animated_sprite):
		return
	_action_animation_left = 0.5 if _using_asset_boss else 0.42
	_play_asset_action(&"attack")

func play_special() -> void:
	if not _using_asset_boss or not is_instance_valid(_animated_sprite):
		play_attack()
		return
	_action_animation_left = 0.5
	_play_asset_action(&"special")

func play_hit() -> void:
	_hit_flash_left = 0.11
	if (_using_asset_creature or _using_asset_boss) and is_instance_valid(_animated_sprite):
		_action_animation_left = 0.22
		_play_asset_action(&"hurt")
	queue_redraw()

func _draw() -> void:
	if _dedicated_mode:
		return
	_draw_boss_attack()
	_draw_mage_attack()
	_draw_elite_status()
	draw_set_transform(Vector2(0.0, _radius * 0.72), 0.0, Vector2(0.9, 0.33))
	draw_circle(Vector2.ZERO, _radius, Color(0.0, 0.0, 0.0, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if is_boss or is_miniboss:
		var seal_color: Color = Color("#e6a35a")
		seal_color.a = 0.5
		draw_arc(Vector2(0.0, 5.0), _radius + 9.0, 0.0, TAU, 36, seal_color, 2.0)
		draw_arc(Vector2(0.0, 5.0), _radius + 13.0, 0.2, TAU - 0.2, 6, Color("#63cbb5"), 1.0)
	elif is_instance_valid(_animated_sprite):
		var ring_color: Color = _color
		ring_color.a = 0.32
		draw_arc(Vector2(0.0, 3.0), _radius + 3.0, 0.0, TAU, 24, ring_color, 1.5)
	else:
		draw_circle(Vector2.ZERO, _radius, _color)
		draw_circle(Vector2(-_radius * 0.28, -_radius * 0.2), _radius * 0.28, _color.lightened(0.32))
		draw_circle(Vector2(-_radius * 0.25, -_radius * 0.08), maxf(2.0, _radius * 0.12), Color("#f9e9d0"))
		draw_circle(Vector2(_radius * 0.28, -_radius * 0.08), maxf(2.0, _radius * 0.12), Color("#f9e9d0"))
	if not (_using_asset_creature or _using_asset_boss):
		_draw_creature_marks()
	var enemy: BaseEnemy = get_parent() as BaseEnemy
	if enemy != null and enemy.alive and (enemy.is_boss or enemy.is_miniboss or enemy.health < enemy.max_health):
		var bar_width: float = 62.0 if enemy.is_boss else (42.0 if enemy.is_miniboss else 30.0)
		var bar_y: float = -43.0 if enemy.is_boss else -35.0
		var bar_rect: Rect2 = Rect2(-bar_width * 0.5, bar_y, bar_width, 5.0)
		draw_rect(bar_rect, Color("#11191d"), true)
		var health_width: float = bar_width * clampf(enemy.health / maxf(1.0, enemy.max_health), 0.0, 1.0)
		var health_color: Color = Color("#e89b55") if enemy.is_boss or enemy.is_miniboss else Color("#d75d5b")
		draw_rect(Rect2(bar_rect.position.x, bar_rect.position.y + 1.0, health_width, 3.0), health_color, true)

func _draw_creature_marks() -> void:
	match archetype:
		&"plague_brute":
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2(side * 8.0, -12.0), Vector2(side * 17.0, -25.0), Color("#d6c18c"), 4.0, true)
				draw_line(Vector2(side * 8.0, -12.0), Vector2(side * 16.0, -3.0), Color("#4c7348"), 5.0, true)
			for spot_index: int in range(3):
				var spot_position: Vector2 = Vector2(-12.0 + float(spot_index) * 12.0, 7.0 + float(spot_index % 2) * 5.0)
				draw_circle(spot_position, 2.6, Color("#d3e38b", 0.75))
		&"bone_archer":
			draw_line(Vector2(-13.0, -9.0), Vector2(11.0, 11.0), Color("#443b33"), 5.0, true)
			draw_line(Vector2(-13.0, -9.0), Vector2(11.0, 11.0), Color("#d2c59e"), 2.0, true)
			draw_line(Vector2(-10.0, 7.0), Vector2(8.0, -11.0), Color("#ece0b8"), 2.0, true)
		&"soul_weaver", &"storm_mage":
			var rune_color: Color = Color("#e6b5ff") if archetype == &"soul_weaver" else Color("#9beaff")
			for rune_index: int in range(4):
				var rune_angle: float = Time.get_ticks_msec() * 0.002 + TAU * float(rune_index) / 4.0
				var rune_center: Vector2 = Vector2.RIGHT.rotated(rune_angle) * (_radius + 8.0)
				var rune_tangent: Vector2 = Vector2.RIGHT.rotated(rune_angle + PI * 0.25) * 3.2
				draw_line(rune_center - rune_tangent, rune_center + rune_tangent, rune_color, 2.0, true)

func _build_sprite_frames() -> SpriteFrames:
	var kind: String = "orc_boss" if is_boss else String(archetype)
	if _frames_by_kind.has(kind):
		return _frames_by_kind[kind] as SpriteFrames
	var frames: SpriteFrames = SpriteFrames.new()
	for animation_name: String in ["idle", "run", "death"]:
		frames.add_animation(StringName(animation_name))
		frames.set_animation_speed(StringName(animation_name), _animation_speed(animation_name))
		frames.set_animation_loop(StringName(animation_name), animation_name != "death")
		var path: String
		if is_boss:
			path = ASSET_ROOT.path_join("orc_boss/%s.png" % animation_name)
		else:
			var sprite_kind: String = kind
			match archetype:
				&"soul_weaver", &"storm_mage":
					sprite_kind = "mage"
				&"bone_archer":
					sprite_kind = "rogue"
				&"plague_brute":
					sprite_kind = "warrior"
			path = ASSET_ROOT.path_join("skeleton_variants/%s/%s.png" % [sprite_kind, animation_name])
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			continue
		var frame_height: int = texture.get_height()
		var frame_width: int = frame_height
		if animation_name == "idle":
			frame_width = 32
		var count: int = maxi(1, floori(float(texture.get_width()) / float(frame_width)))
		for frame_index: int in range(count):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2i(frame_index * frame_width, 0, frame_width, frame_height)
			frames.add_frame(StringName(animation_name), atlas)
	_frames_by_kind[kind] = frames
	return frames

func _build_external_sprite_frames() -> SpriteFrames:
	var cache_key: String = "asset_%s" % visual_species
	if _frames_by_kind.has(cache_key):
		return _frames_by_kind[cache_key] as SpriteFrames
	var frames: SpriteFrames = SpriteFrames.new()
	for action: String in ["idle", "walk", "attack", "hurt", "death", "special"]:
		for direction: String in ["down", "up", "right", "left"]:
			var animation_name: StringName = StringName("%s_%s" % [action, direction])
			frames.add_animation(animation_name)
			frames.set_animation_speed(animation_name, 12.0 if action in ["attack", "hurt", "death", "special"] else (8.0 if action == "walk" else 7.0))
			frames.set_animation_loop(animation_name, action in ["idle", "walk"])
			var texture_path: String = CREATURE_ROOT.path_join(String(visual_species)).path_join("%s_%s.png" % [action, direction])
			var texture: Texture2D = load(texture_path) as Texture2D
			if texture == null:
				continue
			var count: int = maxi(1, floori(float(texture.get_width()) / 16.0))
			for frame_index: int in range(count):
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2i(frame_index * 16, 0, 16, texture.get_height())
				frames.add_frame(animation_name, atlas)
	_frames_by_kind[cache_key] = frames
	return frames

func _build_external_boss_frames() -> SpriteFrames:
	var cache_key: String = "boss_%s" % visual_species
	if _frames_by_kind.has(cache_key):
		return _frames_by_kind[cache_key] as SpriteFrames
	var frames: SpriteFrames = SpriteFrames.new()
	var frame_size: int = int(BOSS_FRAME_SIZES[visual_species])
	for phase: String in ["", "p2_"]:
		for action: String in ["idle", "walk", "attack", "special", "hurt"]:
			var animation_name: StringName = StringName("%s%s" % [phase, action])
			frames.add_animation(animation_name)
			frames.set_animation_speed(animation_name, 12.0 if action in ["attack", "special", "hurt"] else 8.0)
			frames.set_animation_loop(animation_name, action in ["idle", "walk"])
			var texture_path: String = BOSS_ROOT.path_join(String(visual_species)).path_join("%s%s.png" % [phase, action])
			var texture: Texture2D = load(texture_path) as Texture2D
			if texture == null:
				continue
			_add_strip_frames(frames, animation_name, texture, frame_size)
		var death_name: StringName = StringName("%sdeath" % phase)
		frames.add_animation(death_name)
		frames.set_animation_speed(death_name, 12.0)
		frames.set_animation_loop(death_name, false)
		var death_texture: Texture2D = load(BOSS_ROOT.path_join(String(visual_species)).path_join("death.png")) as Texture2D
		if death_texture != null:
			_add_strip_frames(frames, death_name, death_texture, frame_size)
	var roar: Texture2D = load(BOSS_ROOT.path_join(String(visual_species)).path_join("intro_roar.png")) as Texture2D
	frames.add_animation(&"intro_roar")
	frames.set_animation_speed(&"intro_roar", 10.0)
	frames.set_animation_loop(&"intro_roar", false)
	if roar != null:
		_add_strip_frames(frames, &"intro_roar", roar, frame_size)
	_frames_by_kind[cache_key] = frames
	return frames

func _add_strip_frames(frames: SpriteFrames, animation_name: StringName, texture: Texture2D, frame_size: int) -> void:
	var count: int = maxi(1, floori(float(texture.get_width()) / float(frame_size)))
	for frame_index: int in range(count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(frame_index * frame_size, 0, frame_size, texture.get_height())
		frames.add_frame(animation_name, atlas)

func _play_asset_action(action: StringName) -> void:
	var animation: StringName = StringName("%s_%s" % [action, _last_direction]) if _using_asset_creature else action
	if _using_asset_boss and _boss_phase_two and _animated_sprite.sprite_frames.has_animation(StringName("p2_%s" % action)):
		animation = StringName("p2_%s" % action)
	if _animated_sprite.sprite_frames.has_animation(animation) and _animated_sprite.sprite_frames.get_frame_count(animation) > 0:
		_animated_sprite.play(animation)
		_last_animation = animation

func _animation_speed(animation_name: String) -> float:
	if animation_name == "idle":
		return 8.0
	if animation_name == "death":
		return 12.0
	match archetype:
		&"rogue", &"bone_archer", &"storm_mage":
			return 13.0
		&"warrior", &"soul_weaver":
			return 9.0
		&"plague_brute":
			return 7.0
		_:
			return 10.0

func _draw_elite_status() -> void:
	if _elite_modifier == 1:
		var enemy: BaseEnemy = get_parent() as BaseEnemy
		var facing: Vector2 = enemy.facing_direction if enemy != null else Vector2.RIGHT
		draw_arc(Vector2.ZERO, _radius + 12.0, facing.angle() - 0.85, facing.angle() + 0.85, 24, Color("#78d4df"), 4.0)
	elif _elite_modifier == 2:
		draw_arc(Vector2.ZERO, _radius + 8.0, 0.0, TAU, 28, Color("#f16d53"), 2.5)
	elif _elite_modifier == 3:
		draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 40, Color("#a68be2", 0.76), 2.0)
		var aura_color: Color = Color("#a68be2", 0.08 + 0.04 * sin(Time.get_ticks_msec() * 0.006))
		draw_circle(Vector2.ZERO, 56.0, aura_color)
	if _enraged:
		draw_arc(Vector2.ZERO, _radius + 16.0, 0.0, TAU, 28, Color("#ed554a", 0.92), 2.0)

func _draw_boss_attack() -> void:
	if _boss_telegraph_left > 0.0:
		var center: Vector2 = to_local(_boss_telegraph_center)
		var progress: float = 1.0 - _boss_telegraph_left / _boss_telegraph_duration
		var radius: float = _boss_telegraph_radius * (0.82 + 0.18 * progress)
		var alpha: float = 0.12 + 0.18 * absf(sin(Time.get_ticks_msec() * 0.012))
		draw_circle(center, radius, Color(0.86, 0.22, 0.16, alpha))
		draw_arc(center, radius, 0.0, TAU, 64, Color("#ff9571"), 4.0)
		draw_arc(center, radius * (0.22 + 0.55 * progress), 0.0, TAU, 48, Color(1.0, 0.68, 0.43, 0.68), 2.0)
		for index: int in range(8):
			var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 8.0)
			draw_line(center + direction * (radius - 12.0), center + direction * radius, Color("#ffd7a5"), 3.0)
	if _boss_slam_left > 0.0:
		var center: Vector2 = to_local(_boss_telegraph_center)
		var elapsed: float = 1.0 - _boss_slam_left / 0.34
		var radius: float = _boss_telegraph_radius * (0.65 + 0.5 * elapsed)
		var color: Color = Color(1.0, 0.86, 0.56, _boss_slam_left / 0.34)
		draw_arc(center, radius, 0.0, TAU, 72, color, 8.0 * _boss_slam_left / 0.34)

func _draw_mage_attack() -> void:
	if _mage_telegraph_left <= 0.0 and _mage_bolt_left <= 0.0:
		return
	var target_local: Vector2 = to_local(_mage_attack_target)
	if _mage_telegraph_left > 0.0:
		var progress: float = 1.0 - _mage_telegraph_left / 0.82
		var violet: Color = Color("#d7a3ff", 0.28 + 0.45 * progress)
		draw_line(Vector2.ZERO, target_local, violet, 2.0 + 2.0 * progress, true)
		draw_arc(target_local, 27.0 + 5.0 * sin(Time.get_ticks_msec() * 0.018), 0.0, TAU, 32, Color("#e2b7ff"), 2.0)
		for index: int in range(3):
			var orb_angle: float = Time.get_ticks_msec() * 0.004 + TAU * float(index) / 3.0
			var orb: Vector2 = Vector2.RIGHT.rotated(orb_angle) * (9.0 + progress * 12.0)
			draw_circle(orb, 2.2, Color("#f3d6ff"))
	else:
		var fade: float = _mage_bolt_left / 0.2
		draw_line(Vector2.ZERO, target_local, Color(0.86, 0.62, 1.0, fade), 7.0 * fade, true)
		draw_line(Vector2.ZERO, target_local, Color(1.0, 0.9, 1.0, fade), 2.5 * fade, true)
		draw_circle(target_local, 18.0 * fade, Color(0.76, 0.38, 1.0, fade * 0.25))
