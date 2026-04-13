extends Enemy
class_name EnemySoldier

func _ready() -> void:
	is_shielded = true
	max_health = 4
	health = max_health
	speed = 3.6
	attack_damage = 1
	attack_cooldown = 0.8
	body_color = Color(0.24, 0.45, 0.95, 1.0)
	body_scale = Vector3(1.0, 1.0, 1.0)
	super._ready()
