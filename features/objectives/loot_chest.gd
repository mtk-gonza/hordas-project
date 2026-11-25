extends Node2D
class_name LootChest

var chest_id: int = -1
var is_claimed: bool = false
var is_golden: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	var scale_factor: float = 1.42 if is_golden else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	draw_circle(Vector2(0.0, 7.0), 29.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_circle(Vector2.ZERO, 25.0, Color(0.86, 0.58, 0.16, 0.4) if is_golden else Color(0.68, 0.36, 0.11, 0.28))
	draw_rect(Rect2(-17.0, -10.0, 34.0, 24.0), Color("#8a612a") if is_golden else Color("#62412d"), true)
	draw_rect(Rect2(-18.0, -13.0, 36.0, 8.0), Color("#ffe18a") if is_golden else Color("#d6a24f"), true)
	draw_rect(Rect2(-4.0, -4.0, 8.0, 11.0), Color("#fff4c2") if is_golden else Color("#f7d583"), true)
	draw_rect(Rect2(-19.0, 13.0, 38.0, 3.0), Color("#1d2425"), true)
	var glow: Color = Color("#ffe080" if is_golden else "#f2c96d")
	glow.a = 0.5 + 0.25 * sin(float(Time.get_ticks_msec()) * 0.004)
	draw_arc(Vector2.ZERO, 31.0, 0.0, TAU, 32, glow, 3.0 if is_golden else 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

