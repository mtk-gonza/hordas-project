extends Node2D
class_name MapEventVisual

var event_kind: int = 0
var time_left: float = 0.0
var progress: float = 0.0
var health: float = 100.0
var _refresh_left: float = 0.0

func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.08
		queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(0.0, 8.0), 78.0, Color(0.0, 0.0, 0.0, 0.26))
	var pulse: float = 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.004)
	if event_kind == 0:
		var tint: Color = Color("#db655c")
		draw_circle(Vector2.ZERO, 66.0, Color(tint.r, tint.g, tint.b, 0.08 + pulse * 0.08))
		draw_arc(Vector2.ZERO, 70.0, 0.0, TAU, 56, Color("#e78a69"), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -39.0), Vector2(30.0, -4.0), Vector2(13.0, 28.0), Vector2(-15.0, 24.0), Vector2(-31.0, -10.0)]), Color("#56363d"))
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -29.0), Vector2(12.0, -5.0), Vector2(0.0, 16.0), Vector2(-12.0, -5.0)]), Color("#f18a69"))
		var health_rect: Rect2 = Rect2(-44.0, -58.0, 88.0, 7.0)
		draw_rect(health_rect, Color("#171d20"), true)
		draw_rect(Rect2(health_rect.position, Vector2(health_rect.size.x * clampf(health / 120.0, 0.0, 1.0), health_rect.size.y)), Color("#e36f64"), true)
	else:
		var tint: Color = Color("#80e6d0")
		draw_circle(Vector2.ZERO, 58.0, Color(tint.r, tint.g, tint.b, 0.08 + pulse * 0.07))
		draw_arc(Vector2.ZERO, 68.0, 0.0, TAU, 56, Color("#7be1d0"), 3.0)
		draw_circle(Vector2(-10.0, -21.0), 9.0, Color("#d9f7dc"))
		draw_circle(Vector2(10.0, -21.0), 9.0, Color("#d9f7dc"))
		draw_circle(Vector2(0.0, -10.0), 16.0, Color("#d9f7dc"))
		draw_circle(Vector2(-6.0, -12.0), 2.0, Color("#4b716b"))
		draw_circle(Vector2(6.0, -12.0), 2.0, Color("#4b716b"))
		draw_colored_polygon(PackedVector2Array([Vector2(-20.0, 5.0), Vector2(19.0, 5.0), Vector2(13.0, 27.0), Vector2(-13.0, 27.0)]), Color("#599e91"))
		var progress_rect: Rect2 = Rect2(-42.0, -48.0, 84.0, 7.0)
		draw_rect(progress_rect, Color("#171d20"), true)
		draw_rect(Rect2(progress_rect.position, Vector2(progress_rect.size.x * clampf(progress / 24.0, 0.0, 1.0), progress_rect.size.y)), Color("#8ce2bc"), true)
	var countdown: String = "NÚCLEO" if event_kind == 0 else "DRON · %02d s" % ceili(time_left)
	draw_string(ThemeDB.fallback_font, Vector2(-68.0, 91.0), countdown, HORIZONTAL_ALIGNMENT_CENTER, 136.0, 10, Color("#f5e8cf"))
