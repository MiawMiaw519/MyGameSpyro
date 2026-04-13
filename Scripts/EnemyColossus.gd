extends Enemy
class_name EnemyColossus

func _ready() -> void:
	is_giant = true
	max_health = 8
	health = max_health
	speed = 2.8
	attack_damage = 2
	attack_cooldown = 1.2
	attack_range = 2.6
	body_color = Color(0.95, 0.55, 0.15, 1.0)
	body_scale = Vector3(1.35, 1.35, 1.35)
	super._ready()
