extends Label
class_name GemHUD

func _ready() -> void:
	Global.gems_changed.connect(_on_gems_changed)
	_on_gems_changed(Global.total_gems)

func _on_gems_changed(new_amount: int) -> void:
	text = "💎 %d" % new_amount
