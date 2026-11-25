extends Node2D

var radius: float = 340.0
var duration: float = 1.2
var tint: Color = Color("#ffd16b")
var _left: float = 1.2
var texture_path: String = "res://art/external/combat_fx/fire_ultimate_64x64_10f.png"

func _ready() -> void:
	_left = duration
	var strip: Texture2D = load(texture_path) as Texture2D
	if strip == null:
		strip = load("res://art/external/combat_fx/fire_ultimate_64x64_10f.png") as Texture2D
	if strip != null:
		var frames: SpriteFrames = SpriteFrames.new()
		frames.add_animation(&"ultimate")
		frames.set_animation_speed(&"ultimate", 16.0)
		frames.set_animation_loop(&"ultimate", false)
		var count: int = maxi(1, floori(float(strip.get_width()) / 64.0))
		for index: int in range(count):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = strip
			atlas.region = Rect2i(index * 64, 0, 64, 64)
			frames.add_frame(&"ultimate", atlas)
		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.name = "UltimateArtwork"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.sprite_frames = frames
		sprite.scale = Vector2.ONE * 3.6
		sprite.modulate = tint
		sprite.play(&"ultimate")
		add_child(sprite)
	set_process(true)

func _process(delta: float) -> void:
	_left = maxf(0.0, _left - delta)
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress: float = 1.0 - _left / maxf(duration, 0.01)
	var alpha: float = 1.0 - progress
	var burst_radius: float = radius * ease(progress, 0.55)
	var outer: Color = tint
	outer.a = alpha * 0.8
	draw_arc(Vector2.ZERO, burst_radius, 0.0, TAU, 80, outer, 7.0 * (1.0 - progress) + 1.0)
	var inner: Color = Color.WHITE
	inner.a = alpha * 0.32
	draw_arc(Vector2.ZERO, burst_radius * 0.78, 0.0, TAU, 64, inner, 2.0)
	for index: int in range(12):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 12.0)
		draw_line(direction * burst_radius * 0.83, direction * burst_radius, outer, 2.0)

