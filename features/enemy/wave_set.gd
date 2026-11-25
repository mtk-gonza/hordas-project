extends Resource
class_name WaveSet

@export_range(0.0, 600.0, 1.0) var first_minute_rate: float = 20.0
@export_range(0.0, 100.0, 0.5) var additional_per_minute: float = 5.0
@export_range(30.0, 1800.0, 5.0) var boss_time_seconds: float = 300.0
@export_range(10, 1000, 1) var maximum_enemies: int = 250
@export_range(100.0, 2000.0, 10.0) var spawn_radius: float = 700.0
@export_range(100.0, 10000.0, 10.0) var boss_health: float = 1250.0
@export_range(10.0, 300.0, 1.0) var boss_move_speed: float = 52.0
@export_range(20.0, 200.0, 1.0) var boss_separation_radius: float = 74.0
@export_range(1, 1000, 1) var boss_xp_reward: int = 250
@export_range(1.0, 100.0, 1.0) var boss_contact_damage: float = 22.0
