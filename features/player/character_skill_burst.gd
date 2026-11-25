extends Node2D

var radius: float = 245.0
var tint: Color = Color("#ffb64e")
var _time_left: float = 0.62

func _process(delta: float) -> void:
	_time_left = maxf(0.0, _time_left - delta)
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress: float = 1.0 - _time_left / 0.62
	var eased: float = 1.0 - pow(1.0 - progress, 2.4)
	var alpha: float = 1.0 - progress
	var outer_radius: float = radius * eased
	var outer_color: Color = tint
	outer_color.a = alpha * 0.92
	var inner_color: Color = Color.WHITE
	inner_color.a = alpha * 0.45
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 72, outer_color, 7.0 * alpha + 1.0, true)
	draw_arc(Vector2.ZERO, outer_radius * 0.78, 0.0, TAU, 72, inner_color, 2.5 * alpha, true)
	for index: int in range(16):
		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(index) / 16.0)
		var start: Vector2 = direction * outer_radius * 0.84
		var finish: Vector2 = direction * (outer_radius + 18.0 * alpha)
		draw_line(start, finish, outer_color, 3.0 * alpha + 0.5, true)
		var cross: Vector2 = direction.orthogonal() * 5.0 * alpha
		draw_line(finish - cross, finish + cross, inner_color, 2.0 * alpha + 0.5, true)
