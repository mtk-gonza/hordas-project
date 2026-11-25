extends Node2D
class_name BattlePillar

var pillar_id: int = 0
var progress: float = 0.0
var buff_seconds: float = 0.0
var buff_kind: int = 0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var active: bool = buff_seconds > 0.0
	var tint: Color = [Color("#e5a955"), Color("#66d9d2"), Color("#80d478")][posmod(pillar_id, 3)]
	if active:
		tint = [Color("#f3bc66"), Color("#73e9df"), Color("#91ea7b")][posmod(buff_kind, 3)]
	draw_circle(Vector2(0.0, 8.0), 36.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.72), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0.0, -25.0), Vector2(18.0, -7.0), Vector2(13.0, 17.0), Vector2(-13.0, 17.0), Vector2(-18.0, -7.0)]), Color("#344044"))
	draw_line(Vector2(0.0, -16.0), Vector2.ZERO, tint, 3.0)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, 40.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 40, Color("#f4e3bd"), 3.0)
	if active:
		draw_circle(Vector2.ZERO, 5.0, tint)

