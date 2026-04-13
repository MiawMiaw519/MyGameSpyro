extends Enemy
class_name EnemyFroussard

@export var flee_distance: float = 4.5
@export var spider_scene: PackedScene = preload("res://Assets/spyro-the-dragon-reignited/spider-enemy/source/Attack.fbx")
@export var spider_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var spider_position: Vector3 = Vector3(0.0, 0.05, 0.0)
@export var spider_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)

var _spider_root: Node3D
var _spider_anim_player: AnimationPlayer
var _spider_attack_anim: StringName = &""
var _spider_move_anim: StringName = &""
var _spider_idle_anim: StringName = &""
var _current_spider_anim: StringName = &""
var _current_spider_speed: float = 1.0
var _prev_attack_timer: float = 0.0
var _attack_anim_timer: float = 0.0

func _ready() -> void:
	max_health = 2
	health = max_health
	speed = 5.2
	attack_damage = 1
	attack_cooldown = 1.1
	detection_range = 30.0
	attack_range = 2.1
	health_bar_height = 1.9
	health_bar_width = 1.5
	health_bar_thickness = 0.18
	body_color = Color(0.25, 0.85, 0.45, 1.0)
	body_scale = Vector3(0.9, 0.9, 0.9)
	super._ready()
	_setup_spider_visuals()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_spider_animation(delta)

func _get_move_direction(to_player: Vector3, distance: float) -> Vector3:
	if player and player.current_state == Player.State.CHARGING and distance < 12.0:
		return -to_player.normalized()
	if distance < flee_distance:
		return -to_player.normalized()
	return to_player.normalized()

func _setup_spider_visuals() -> void:
	var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
		capsule.radius = 0.65
		capsule.height = 1.0
		collision_shape.position.y = 0.6

	if spider_scene == null:
		return

	_spider_root = spider_scene.instantiate() as Node3D
	if _spider_root == null:
		return

	_spider_root.name = "SpiderVisual"
	add_child(_spider_root)
	_spider_root.position = spider_position
	_spider_root.scale = spider_scale
	_spider_root.rotation_degrees = spider_rotation_degrees

	if not _has_visible_mesh(_spider_root):
		push_warning("Spider model has no visible mesh. Keeping fallback capsule visible.")
		_spider_root.queue_free()
		_spider_root = null
		return

	if mesh_instance:
		mesh_instance.visible = false

	_spider_anim_player = _find_animation_player(_spider_root)
	_resolve_spider_animations()
	_play_spider_animation(_spider_idle_anim if _spider_idle_anim != &"" else _spider_move_anim, 0.85)

func _has_visible_mesh(node: Node) -> bool:
	if node is MeshInstance3D:
		var m: MeshInstance3D = node as MeshInstance3D
		if m.mesh != null and m.visible:
			return true
	for child in node.get_children():
		if _has_visible_mesh(child):
			return true
	return false

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
	return null

func _resolve_spider_animations() -> void:
	if _spider_anim_player == null:
		return

	var anims: PackedStringArray = _spider_anim_player.get_animation_list()
	if anims.is_empty():
		return

	for anim_name in anims:
		var lower: String = String(anim_name).to_lower()
		if _spider_attack_anim == &"" and lower.contains("attack"):
			_spider_attack_anim = StringName(anim_name)
		if _spider_move_anim == &"" and (lower.contains("walk") or lower.contains("run") or lower.contains("move")):
			_spider_move_anim = StringName(anim_name)
		if _spider_idle_anim == &"" and lower.contains("idle"):
			_spider_idle_anim = StringName(anim_name)

	if _spider_attack_anim == &"":
		_spider_attack_anim = StringName(anims[0])
	if _spider_move_anim == &"":
		_spider_move_anim = _spider_attack_anim
	if _spider_idle_anim == &"":
		_spider_idle_anim = _spider_move_anim

func _update_spider_animation(delta: float) -> void:
	if _spider_anim_player == null:
		return

	# Detect attack trigger (timer jumps up when _attack_player() is called)
	if _attack_timer > _prev_attack_timer + 0.2:
		_attack_anim_timer = 0.28
		_play_spider_animation(_spider_attack_anim, 1.25)
	_prev_attack_timer = _attack_timer

	if _attack_anim_timer > 0.0:
		_attack_anim_timer -= delta
		return

	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.2:
		var speed_scale: float = clampf(horizontal_speed / max(speed, 0.01), 0.8, 1.55)
		_play_spider_animation(_spider_move_anim, speed_scale)
	else:
		_play_spider_animation(_spider_idle_anim, 0.85)

func _play_spider_animation(anim_name: StringName, anim_speed: float = 1.0) -> void:
	if _spider_anim_player == null or anim_name == &"":
		return
	if not _spider_anim_player.has_animation(String(anim_name)):
		return

	var speed_changed: bool = absf(_current_spider_speed - anim_speed) > 0.05
	if _current_spider_anim != anim_name:
		_spider_anim_player.play(String(anim_name), 0.12, anim_speed)
		_current_spider_anim = anim_name
		_current_spider_speed = anim_speed
	elif speed_changed:
		_spider_anim_player.speed_scale = anim_speed
		_current_spider_speed = anim_speed
