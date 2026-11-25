extends Node2D
class_name AnimatedStripEffect

var texture_path: String = ""
var frame_size: int = 32
var frame_count: int = 6
var playback_fps: float = 14.0
var effect_scale: float = 2.0
var tint: Color = Color.WHITE

func _ready() -> void:
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null or frame_size <= 0:
		queue_free()
		return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"effect")
	frames.set_animation_speed(&"effect", playback_fps)
	frames.set_animation_loop(&"effect", false)
	var actual_count: int = mini(frame_count, floori(float(texture.get_width()) / float(frame_size)))
	for index: int in range(actual_count):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2i(index * frame_size, 0, frame_size, texture.get_height())
		frames.add_frame(&"effect", atlas)
	if actual_count <= 0:
		queue_free()
		return
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * effect_scale
	sprite.modulate = tint
	sprite.animation_finished.connect(queue_free)
	add_child(sprite)
	sprite.play(&"effect")
