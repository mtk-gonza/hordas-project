extends Node

const MENU_SCENE_PATH: String = "res://scenes/menus/main_menu.tscn"
const DEDICATED_SCENE_PATH: String = "res://scenes/session/dedicated_server.tscn"

func _ready() -> void:
	var next_scene: String = DEDICATED_SCENE_PATH if NetworkManager.is_dedicated_mode() else MENU_SCENE_PATH
	call_deferred("_open_scene", next_scene)

func _open_scene(scene_path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("No se pudo cargar la escena de inicio %s (error %d)." % [scene_path, error])
