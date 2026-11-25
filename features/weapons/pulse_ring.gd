extends Node2D

const BURST_TEXTURE: Texture2D = preload("res://art/external/combat_fx/fire_burst_48x48_8f.png")

@export var max_radius: float = 118.0
@export var duration: float = 0.32
@export var evolved: bool = false
@export var evolution_color: Color = Color("#a9f3ee")

var _remaining: float = 0.32

func _ready() -> void:
	_remaining = duration
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = "AnimatedImpact"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = _build_burst_frames()
	sprite.scale = Vector2.ONE * maxf(1.0, max_radius * 2.0 / 48.0 * 0.82)
	sprite.position.y = -12.0
	sprite.modulate = evolution_color if evolved else Color.WHITE
	sprite.play(&"burst")
	add_child(sprite)
	set_process(true)

func _build_burst_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"burst")
	frames.set_animation_speed(&"burst", 20.0)
	frames.set_animation_loop(&"burst", false)
	var count: int = maxi(1, floori(float(BURST_TEXTURE.get_width()) / 48.0))
	for index: int in range(count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = BURST_TEXTURE
		atlas.region = Rect2i(index * 48, 0, 48, 48)
		frames.add_frame(&"burst", atlas)
	return frames

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress: float = 1.0 - _remaining / maxf(duration, 0.001)
	var alpha: float = 1.0 - progress
	var ring_radius: float = max_radius * progress
	var amber: Color = evolution_color if evolved else Color("#ffd17e")
	amber.a = alpha * 0.9
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 42, amber, 3.0, false)
	var teal: Color = evolution_color.lightened(0.25) if evolved else Color("#6de2cd")
	teal.a = alpha * 0.55
	draw_arc(Vector2.ZERO, ring_radius * 0.82, 0.0, TAU, 36, teal, 1.5, false)
	for index: int in range(12 if evolved else 8):
		var angle: float = TAU * float(index) / float(12 if evolved else 8)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var inner: Vector2 = direction * ring_radius * 0.88
		var outer: Vector2 = direction * ring_radius
		draw_line(inner, outer, amber, 2.0, false)
