extends CharacterBody3D
class_name Enemy

signal health_changed(current: int, max_value: int)
signal died(enemy: Enemy)

@export var max_health: int = 3
@export var health: int = 3
@export var is_shielded: bool = false
@export var is_giant: bool = false

@export var speed: float = 4.0
@export var acceleration: float = 10.0
@export var detection_range: float = 26.0
@export var attack_range: float = 2.2
@export var attack_cooldown: float = 0.9
@export var attack_damage: int = 1
@export var hit_stun_duration: float = 0.12

@export var body_color: Color = Color(0.9, 0.2, 0.2, 1.0)
@export var body_scale: Vector3 = Vector3.ONE
@export var health_bar_height: float = 2.4
@export var health_bar_width: float = 1.9
@export var health_bar_thickness: float = 0.2

var player: Player = null
var _attack_timer: float = 0.0
var _hit_stun_timer: float = 0.0

var _health_bar_root: Node3D
var _health_bar_bg: MeshInstance3D
var _health_bar_fill: MeshInstance3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("enemies")
	_acquire_player()
	if max_health <= 0:
		max_health = 1
	health = clampi(health, 1, max_health)
	_apply_visual_style(body_color, body_scale)
	_create_health_bar()
	_update_health_bar_visual()
	health_changed.emit(health, max_health)

func _acquire_player() -> void:
	var found_player: Node = get_tree().get_first_node_in_group("player")
	if found_player is Player:
		player = found_player

func _apply_visual_style(color: Color, scale_value: Vector3 = Vector3.ONE) -> void:
	if mesh_instance == null:
		return
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.05
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	mesh_instance.scale = scale_value

func _create_health_bar() -> void:
	if _health_bar_root != null:
		return

	_health_bar_root = Node3D.new()
	_health_bar_root.name = "HealthBar3D"
	add_child(_health_bar_root)
	var y_offset: float = health_bar_height * maxf(body_scale.y, 1.0)
	_health_bar_root.position = Vector3(0.0, y_offset, 0.0)

	var bg_mesh: QuadMesh = QuadMesh.new()
	bg_mesh.size = Vector2(health_bar_width, health_bar_thickness)
	_health_bar_bg = MeshInstance3D.new()
	_health_bar_bg.mesh = bg_mesh
	_health_bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar_root.add_child(_health_bar_bg)

	var fill_mesh: QuadMesh = QuadMesh.new()
	fill_mesh.size = Vector2(health_bar_width, health_bar_thickness * 0.75)
	_health_bar_fill = MeshInstance3D.new()
	_health_bar_fill.mesh = fill_mesh
	_health_bar_fill.position = Vector3(0.0, 0.0, 0.01)
	_health_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar_root.add_child(_health_bar_fill)

	var bg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.no_depth_test = true
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_mat.albedo_color = Color(0.05, 0.05, 0.05, 0.9)
	_health_bar_bg.material_override = bg_mat

	var fill_mat: StandardMaterial3D = StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.no_depth_test = true
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.albedo_color = Color(0.1, 0.9, 0.2, 0.95)
	_health_bar_fill.material_override = fill_mat

func _update_health_bar_transform() -> void:
	if _health_bar_root == null or not is_inside_tree():
		return
	var y_offset: float = health_bar_height * maxf(body_scale.y, 1.0)
	_health_bar_root.position = Vector3(0.0, y_offset, 0.0)
	var viewport_ref: Viewport = get_viewport()
	if viewport_ref == null:
		return
	var cam: Camera3D = viewport_ref.get_camera_3d()
	if cam and cam.is_inside_tree():
		_health_bar_root.look_at(cam.global_position, Vector3.UP, true)

func _update_health_bar_visual() -> void:
	if _health_bar_fill == null:
		return

	var ratio: float = 0.0
	if max_health > 0:
		ratio = clampf(float(health) / float(max_health), 0.0, 1.0)

	_health_bar_fill.scale.x = max(0.001, ratio)
	_health_bar_fill.position.x = (-health_bar_width * 0.5) + (health_bar_width * 0.5 * ratio)

	var fill_mat: StandardMaterial3D = _health_bar_fill.material_override as StandardMaterial3D
	if fill_mat:
		fill_mat.albedo_color = Color(1.0 - ratio, 0.2 + ratio * 0.8, 0.12, 0.95)

	if _health_bar_root:
		_health_bar_root.visible = health > 0

func is_vulnerable_to_damage_type(type: String) -> bool:
	match type:
		"flame":
			return not is_shielded
		"charge":
			return not is_giant
		_:
			return true

func take_damage(type: String) -> bool:
	if not is_vulnerable_to_damage_type(type):
		match type:
			"flame":
				print("Shielded! No damage from flame.")
			"charge":
				print("Too big! No damage from charge.")
			_:
				pass
		return false

	var damage: int = 0
	match type:
		"flame":
			damage = 1
		"charge":
			damage = 2
		"melee":
			damage = 2
		_:
			damage = 1

	if damage <= 0:
		return false

	health = max(0, health - damage)
	_hit_stun_timer = hit_stun_duration
	_update_health_bar_visual()
	health_changed.emit(health, max_health)

	if health <= 0:
		die()

	return true

func die() -> void:
	died.emit(self)
	queue_free()

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_acquire_player()

	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _hit_stun_timer > 0.0:
		_hit_stun_timer -= delta

	if not is_on_floor():
		velocity += get_gravity() * delta

	var horizontal_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var desired_velocity: Vector3 = Vector3.ZERO

	if player and _can_detect_player():
		var to_player: Vector3 = player.global_position - global_position
		to_player.y = 0.0
		var distance: float = to_player.length()
		var direction: Vector3 = _get_move_direction(to_player, distance)

		if _hit_stun_timer <= 0.0 and direction.length() > 0.01:
			desired_velocity = direction.normalized() * speed
			_look_at_direction(direction, delta)
		elif distance <= attack_range:
			_look_at_direction(to_player, delta)

		if distance <= attack_range and _attack_timer <= 0.0:
			_attack_player()
	else:
		desired_velocity = Vector3.ZERO

	horizontal_velocity = horizontal_velocity.lerp(desired_velocity, clampf(acceleration * delta, 0.0, 1.0))
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	move_and_slide()
	_update_health_bar_transform()

func _can_detect_player() -> bool:
	if player == null:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func _get_move_direction(to_player: Vector3, _distance: float) -> Vector3:
	if to_player.length() < 0.001:
		return Vector3.ZERO
	return to_player.normalized()

func _look_at_direction(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)

func _attack_player() -> void:
	if player == null:
		return
	_attack_timer = attack_cooldown
	if player.has_method("take_damage"):
		player.call("take_damage", attack_damage, global_position)
	else:
		Global.respawn_player(player)
