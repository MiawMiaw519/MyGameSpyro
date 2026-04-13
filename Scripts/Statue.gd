extends Area3D
class_name StatueCheckpoint

@export var tutorial_text: String = "Libérez-moi !"

var _is_liberated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _is_liberated:
		return
	if not body is Player:
		return

	_is_liberated = true
	Global.set_checkpoint(global_position)
	print("[STATUE] ", tutorial_text)
