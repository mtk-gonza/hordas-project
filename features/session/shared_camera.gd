extends Camera2D
class_name SharedBattleCamera

@export var follow_speed: float = 8.0
@export var min_zoom: float = 0.62
@export var max_zoom: float = 1.0
@export var safety_margin: float = 0.82

func _ready() -> void:
	position_smoothing_enabled = false
	zoom = Vector2.ONE * max_zoom
	set_process(true)

func _process(delta: float) -> void:
	var players: Array[Player] = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		var player: Player = node as Player
		if player != null and not player.replicated_dead:
			players.append(player)
	if players.is_empty():
		return
	var center: Vector2 = Vector2.ZERO
	for player: Player in players:
		center += player.global_position
	center /= float(players.size())
	var farthest: float = 0.0
	for player: Player in players:
		farthest = maxf(farthest, center.distance_to(player.global_position))
	var viewport_half: float = minf(get_viewport_rect().size.x, get_viewport_rect().size.y) * 0.5
	var target_scale: float = clampf(viewport_half * safety_margin / maxf(120.0, farthest + 120.0), min_zoom, max_zoom)
	var target_zoom: Vector2 = Vector2.ONE * target_scale
	global_position = global_position.lerp(center, 1.0 - exp(-follow_speed * delta))
	zoom = zoom.lerp(target_zoom, 1.0 - exp(-follow_speed * delta))

