extends Node2D
class_name AccessCardDrop

var card_id: int = -1
var _phase: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_phase = float(card_id % 13) * 0.47

func _process(delta: float) -> void:
	_phase += delta
	queue_redraw()

func _draw() -> void:
	var bob: float = sin(_phase * 2.2) * 3.0
	draw_circle(Vector2(0.0, 5.0), 27.0, Color(0.16, 0.78, 0.76, 0.14))
	draw_circle(Vector2(0.0, 5.0), 18.0, Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(-12.0, -17.0 + bob, 24.0, 32.0), Color("#102326"), true)
	draw_rect(Rect2(-10.0, -15.0 + bob, 20.0, 28.0), Color("#62cfc1"), true)
	draw_rect(Rect2(-7.0, -11.0 + bob, 14.0, 20.0), Color("#1b3438"), true)
	draw_rect(Rect2(-4.0, -8.0 + bob, 8.0, 4.0), Color("#f1ca73"), true)
	draw_rect(Rect2(-4.0, 0.0 + bob, 8.0, 7.0), Color("#87e7d2"), true)
	draw_rect(Rect2(-2.0, 3.0 + bob, 4.0, 9.0), Color("#87e7d2"), true)
	draw_arc(Vector2.ZERO, 25.0 + sin(_phase * 3.0) * 2.0, 0.0, TAU, 24, Color(0.45, 0.9, 0.8, 0.58), 1.5)
