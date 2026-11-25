extends Resource
class_name UltimateDefinition

@export var ability_id: StringName = &"sunburst"
@export var display_name: String = "Ráfaga Solar"
@export_range(40.0, 1200.0, 1.0) var damage: float = 170.0
@export_range(80.0, 900.0, 1.0) var radius: float = 360.0
@export_range(10.0, 180.0, 1.0) var cooldown: float = 55.0
@export_range(0.2, 5.0, 0.1) var effect_duration: float = 1.2
@export var effect_color: Color = Color("#ffd16b")

