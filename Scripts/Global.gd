extends Node
class_name GlobalState

signal gems_changed(new_amount: int)
signal checkpoint_updated(position: Vector3)
signal level_completed(level_id: String)

var total_gems: int = 0:
	set(value):
		total_gems = value
		gems_changed.emit(total_gems)

var current_checkpoint_pos: Vector3 = Vector3.ZERO
var has_checkpoint: bool = false

# Ex: {"level1": true, "level2": true}
var completed_levels: Dictionary = {}

func add_gems(amount: int) -> void:
	total_gems += amount

func set_checkpoint(position: Vector3) -> void:
	current_checkpoint_pos = position
	has_checkpoint = true
	checkpoint_updated.emit(position)

func mark_level_completed(level_id: String) -> void:
	if level_id.is_empty():
		return
	if completed_levels.get(level_id, false):
		return
	completed_levels[level_id] = true
	level_completed.emit(level_id)
	print("[GLOBAL] Niveau terminé: ", level_id)

func has_completed_level(level_id: String) -> bool:
	return completed_levels.get(level_id, false)

func has_completed_all(level_ids: Array[String]) -> bool:
	for level_id in level_ids:
		if not has_completed_level(level_id):
			return false
	return true

func respawn_player(player: CharacterBody3D) -> void:
	if has_checkpoint:
		player.global_position = current_checkpoint_pos
		player.velocity = Vector3.ZERO
	else:
		get_tree().reload_current_scene()
