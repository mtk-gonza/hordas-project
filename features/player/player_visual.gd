extends Node2D
class_name PlayerVisual

@export var sprite_frames: SpriteFrames

const ART_ROOT: String = "res://art/external/pixel_crawler/game/player/"
const FRAME_SIZE: Vector2i = Vector2i(64, 64)
const ANIMATION_SPEED: float = 9.0
const PLAYER_TINTS: Array[Color] = [Color("#a5fff0"), Color("#b9d0ff"), Color("#ffd28e"), Color("#ffc0dc")]

var _body_color: Color = Color("#45c4ba")
var _facing: Vector2 = Vector2.RIGHT
var _state: StringName = &"idle"
var _direction: StringName = &"down"
var _is_downed: bool = false
var _revive_progress: float = 0.0
var _palette_index: int = 0
var _dedicated_mode: bool = false
var _weapon_trail_left: float = 0.0
var _weapon_trail_start: Vector2 = Vector2.ZERO
var _weapon_trail_end: Vector2 = Vector2.ZERO
var _weapon_trail_kind: int = 0
var _attack_flash_left: float = 0.0
var _attack_flash_total: float = 0.24
static var _shared_sprite_frames: SpriteFrames
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if NetworkManager.is_dedicated_mode():
		_dedicated_mode = true
		_animated_sprite.visible = false
		set_process(false)
		return
	if sprite_frames == null:
		sprite_frames = _build_sprite_frames()
	_animated_sprite.sprite_frames = sprite_frames
	_animated_sprite.visible = sprite_frames != null
	_animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_animated_sprite.scale = Vector2(2.65, 2.65)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_weapon_trail_left = maxf(0.0, _weapon_trail_left - delta)
	_attack_flash_left = maxf(0.0, _attack_flash_left - delta)
	var player: Player = get_parent() as Player
	if _weapon_trail_left > 0.0 or _attack_flash_left > 0.0 or (player != null and player.replicated_blade_level > 0):
		queue_redraw()

func set_player_style(peer_id: int) -> void:
	var colors: Array[Color] = [Color("#45c4ba"), Color("#78a9ff"), Color("#f0b35c"), Color("#e87aa8")]
	var palette_index: int = posmod(peer_id - 1, colors.size())
	_palette_index = palette_index
	_body_color = colors[palette_index]
	if is_instance_valid(_animated_sprite):
		_animated_sprite.modulate = PLAYER_TINTS[palette_index]
	queue_redraw()

func set_animation_state(state: StringName, facing: Vector2) -> void:
	if state == &"attack" and _state != &"attack":
		_attack_flash_left = _attack_flash_total
	_state = state
	_facing = facing
	_direction = _direction_for(facing)
	var animation: StringName = StringName("%s_%s" % [state, _direction])
	if sprite_frames != null and sprite_frames.has_animation(animation):
		_animated_sprite.visible = true
		if _animated_sprite.animation != animation:
			_animated_sprite.play(animation)
		elif not _animated_sprite.is_playing() and state != &"death":
			_animated_sprite.play(animation)
		_animated_sprite.flip_h = _direction == &"side" and facing.x < 0.0
	else:
		_animated_sprite.visible = false
	queue_redraw()

func set_downed(downed: bool, revive_progress: float) -> void:
	_is_downed = downed
	_revive_progress = clampf(revive_progress, 0.0, 1.0)
	if is_instance_valid(_animated_sprite):
		_animated_sprite.modulate = Color("#bb6372") if downed else PLAYER_TINTS[_palette_index]
	queue_redraw()

@rpc("authority", "call_local", "unreliable")
func replicate_weapon_trail(target_world_position: Vector2, kind: int) -> void:
	var player: Player = get_parent() as Player
	if player == null or NetworkManager.is_dedicated_mode():
		return
	_weapon_trail_start = to_local(player.global_position)
	_weapon_trail_end = to_local(target_world_position)
	_weapon_trail_kind = clampi(kind, 0, 1)
	_weapon_trail_left = 0.18 if _weapon_trail_kind == 0 else 0.22
	queue_redraw()

func _direction_for(facing: Vector2) -> StringName:
	if absf(facing.x) > absf(facing.y):
		return &"side"
	return &"down" if facing.y >= 0.0 else &"up"

func _build_sprite_frames() -> SpriteFrames:
	if _shared_sprite_frames != null:
		return _shared_sprite_frames
	var frames: SpriteFrames = SpriteFrames.new()
	for state: String in ["idle", "run", "attack", "death"]:
		for direction: String in ["down", "side", "up"]:
			var animation: StringName = StringName("%s_%s" % [state, direction])
			frames.add_animation(animation)
			var playback_speed: float = 8.0 if state == "idle" else (15.0 if state == "attack" else ANIMATION_SPEED)
			frames.set_animation_speed(animation, playback_speed)
			frames.set_animation_loop(animation, state != "death")
			var sheet_path: String = _sheet_path(state, direction)
			var texture: Texture2D = load(sheet_path) as Texture2D
			if texture == null:
				continue
			_add_sheet_frames(frames, animation, texture, FRAME_SIZE)
	_shared_sprite_frames = frames
	return _shared_sprite_frames

func _sheet_path(state: String, direction: String) -> String:
	return ART_ROOT.path_join("%s_%s.png" % [state, direction])

func _add_sheet_frames(frames: SpriteFrames, animation: StringName, texture: Texture2D, frame_size: Vector2i) -> void:
	var frame_count: int = maxi(1, floori(float(texture.get_width()) / float(frame_size.x)))
	for index: int in range(frame_count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(index * frame_size.x, 0, frame_size.x, frame_size.y)
		frames.add_frame(animation, atlas)

func _draw() -> void:
	if _dedicated_mode:
		return
	_draw_secondary_weapons()
	if _weapon_trail_left > 0.0:
		var fade: float = clampf(_weapon_trail_left / 0.22, 0.0, 1.0)
		var trail_color: Color = Color("#8feaff") if _weapon_trail_kind == 0 else Color("#ffe29a")
		trail_color.a = fade
		draw_line(_weapon_trail_start, _weapon_trail_end, trail_color, 4.0 if _weapon_trail_kind == 0 else 3.0, true)
		draw_circle(_weapon_trail_end, 4.0 * fade, trail_color)
	if _attack_flash_left > 0.0:
		_draw_attack_sweep()
	if _is_downed:
		var downed_tint: Color = Color("#e77982")
		draw_circle(Vector2(0.0, 19.0), 39.0, Color(0.3, 0.02, 0.04, 0.22))
		draw_arc(Vector2(0.0, 19.0), 38.0, 0.0, TAU, 48, downed_tint, 2.0)
		draw_arc(Vector2(0.0, 19.0), 44.0, -PI * 0.5, -PI * 0.5 + TAU * _revive_progress, 48, Color("#72e0bd"), 4.0)
	if _animated_sprite.visible:
		var ring: Color = _body_color
		ring.a = 0.88
		draw_circle(Vector2(0.0, 21.0), 19.0, Color(0.0, 0.0, 0.0, 0.25))
		draw_arc(Vector2(0.0, 18.0), 18.0, 0.0, TAU, 32, ring, 2.5, true)
		return
	var bob: float = 0.0
	if _state == &"run":
		bob = sin(Time.get_ticks_msec() * 0.018) * 2.5
	var center: Vector2 = Vector2(0.0, bob)
	draw_circle(center + Vector2(0.0, 4.0), 17.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_circle(center, 15.0, _body_color)
	draw_circle(center + Vector2(0.0, -3.0), 10.0, _body_color.lightened(0.25))
	draw_circle(center + _facing.normalized() * 6.0 + Vector2(0.0, -4.0), 2.3, Color("#14232b"))
	if _state == &"attack":
		draw_arc(center, 30.0, -0.8, 1.6, 28, Color("#ffe88a"), 3.0, true)
	if _state == &"death":
		draw_line(Vector2(-8.0, -8.0), Vector2(8.0, 8.0), Color.WHITE, 3.0)
		draw_line(Vector2(8.0, -8.0), Vector2(-8.0, 8.0), Color.WHITE, 3.0)

func _draw_secondary_weapons() -> void:
	var player: Player = get_parent() as Player
	if player == null or player.replicated_blade_level <= 0:
		return
	var blade_count: int = mini(5, 1 + int(player.replicated_blade_level >= 2) + int(player.replicated_blade_level >= 4) + int(player.replicated_blade_level >= 5) + int(player.replicated_blade_evolved))
	var orbit_radius: float = 24.0 + float(player.replicated_blade_level) * 5.0 + (8.0 if player.replicated_blade_evolved else 0.0)
	var rotation: float = float(Time.get_ticks_msec()) * (0.0025 + float(player.replicated_blade_level) * 0.00035)
	for index: int in range(blade_count):
		var angle: float = rotation + TAU * float(index) / float(blade_count)
		var center: Vector2 = Vector2.RIGHT.rotated(angle) * orbit_radius
		var tangent: Vector2 = Vector2.RIGHT.rotated(angle + PI * 0.5)
		var blade_color: Color = Color("#d6bcff") if player.replicated_blade_evolved else Color("#b8eeef")
		draw_line(center - tangent * 7.0, center + tangent * 7.0, Color("#152127"), 6.0, true)
		draw_line(center - tangent * 6.0, center + tangent * 6.0, blade_color, 3.0, true)

func _draw_attack_sweep() -> void:
	var progress: float = 1.0 - _attack_flash_left / _attack_flash_total
	var fade: float = 1.0 - progress
	var direction: Vector2 = _facing.normalized() if _facing.length_squared() > 0.01 else Vector2.RIGHT
	var slash_center: Vector2 = direction * 16.0
	var slash_color: Color = _body_color.lightened(0.48)
	slash_color.a = fade * 0.94
	var glint_color: Color = Color("#fff9dd", fade * 0.76)
	draw_set_transform(slash_center, direction.angle() - 0.85 + progress * 1.55, Vector2.ONE)
	draw_arc(Vector2.ZERO, 37.0 + 8.0 * sin(progress * PI), -0.95, 0.95, 28, Color("#18202a", fade * 0.8), 8.0 * fade, true)
	draw_arc(Vector2.ZERO, 37.0 + 8.0 * sin(progress * PI), -0.95, 0.95, 28, slash_color, 4.0 * fade, true)
	draw_arc(Vector2.ZERO, 28.0 + 6.0 * progress, -0.66, 0.66, 24, glint_color, 1.5 * fade, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var spark_point: Vector2 = slash_center + direction.rotated(-0.25 + progress * 0.5) * 48.0
	draw_line(spark_point - direction.rotated(0.7) * 5.0, spark_point + direction.rotated(0.7) * 5.0, glint_color, 2.0 * fade, true)
