extends RefCounted
class_name ProfileStore

func open() -> bool:
	return false

func load_profile(_account_id: String) -> Dictionary:
	return {}

func save_profile(_account_id: String, _profile: AccountProfile) -> bool:
	return false

func close() -> void:
	pass
