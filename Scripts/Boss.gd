extends CharacterBody3D
class_name Boss

signal boss_defeated
signal health_changed(current_health: float, max_health: float)
signal phase_changed(phase: int, message: String)
signal phase1_timer_changed(remaining: float, total: float)

enum Phase { PHASE1, PHASE2, PHASE3 }

@export var projectile_scene: PackedScene
@export var boss_model_scene: PackedScene = preload("res://calmaramon.glb")
@export var model_scale: Vector3 = Vector3(8.8, 8.8, 8.8)
@export var model_position: Vector3 = Vector3(0.0, -7.6, 0.0)
@export var model_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)

@export var melee_windup_time: float = 0.26
@export var melee_hit_grace_range_multiplier: float = 1.35
@export var camera_shake_attack: float = 0.12
@export var camera_shake_hurt: float = 0.08
@export var camera_shake_death: float = 0.22

@export var max_health: float = 100.0
@export var detection_range: float = 38.0
@export var attack_range: float = 11.0
@export var move_speed: float = 5.4

@export var arena_center: Vector3 = Vector3.ZERO
@export var arena_half_extent_x: float = 48.0
@export var arena_half_extent_z: float = 48.0
@export var projectile_spawn_height: float = 26.0
@export var projectile_edge_margin: float = 3.0
@export var acceleration: float = 7.5
@export var attack_cooldown: float = 1.2
@export var melee_damage: int = 2
@export var phase2_flame_damage: float = 4.0
@export var phase3_charge_damage: float = 8.0
@export var aggro_immediately_on_spawn: bool = true
@export var phase1_survival_duration: float = 18.0

@export var projectiles_min_per_volley: int = 12
@export var projectiles_max_per_volley: int = 34
@export var projectile_interval_max: float = 2.1
@export var projectile_interval_min: float = 0.58
@export var phase2_density_multiplier: float = 1.2
@export var phase3_density_multiplier: float = 1.45

@export var targeted_salvo_enabled: bool = true
@export var targeted_projectiles_min_per_volley: int = 4
@export var targeted_projectiles_max_per_volley: int = 18
@export var targeted_radius_max: float = 12.0
@export var targeted_radius_min: float = 3.5
@export var targeted_ring_jitter: float = 1.8
@export var targeted_center_strikes_chance: float = 0.22

var current_phase: Phase = Phase.PHASE1
var health: float = 100.0

var _player: Player = null
var _attack_timer: float = 0.0
var _anim_lock_timer: float = 0.0
var _hurt_flash_timer: float = 0.0
var _phase1_elapsed: float = 0.0
var _is_dying: bool = false

var _visual_root: Node3D = null
var _anim_player: AnimationPlayer = null

var _anim_idle: StringName = &""
var _anim_move: StringName = &""
var _anim_attack_front: StringName = &""
var _anim_attack_back: StringName = &""
var _anim_hurt: StringName = &""
var _anim_death: StringName = &""
var _current_anim: StringName = &""
var _current_speed: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _camera_shake_tween: Tween = null

@onready var timer: Timer = $Timer
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	randomize()
	_rng.randomize()
	health = max_health
	_phase1_elapsed = 0.0
	health_changed.emit(health, max_health)
	phase_changed.emit(current_phase, get_phase_display_text(current_phase))
	phase1_timer_changed.emit(get_phase1_time_remaining(), phase1_survival_duration)
	_acquire_player()
	_setup_boss_visuals()

	if timer and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	if timer:
		timer.wait_time = _get_projectile_interval()
		timer.start()

	_play_anim(_anim_idle, 1.0)

func _physics_process(delta: float) -> void:
	if _is_dying:
		return

	if _player == null or not is_instance_valid(_player):
		_acquire_player()

	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _anim_lock_timer > 0.0:
		_anim_lock_timer -= delta
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta

	_update_phase1_survival(delta)

	if not is_on_floor():
		velocity += get_gravity() * delta

	var desired_horizontal: Vector3 = Vector3.ZERO

	if _player and _can_detect_player():
		var to_player: Vector3 = _player.global_position - global_position
		to_player.y = 0.0
		var distance: float = to_player.length()
		if distance > 0.01:
			_look_at_direction(to_player, delta)

		if distance > attack_range * 0.95:
			desired_horizontal = to_player.normalized() * _get_phase_speed_multiplier() * move_speed
		elif _attack_timer <= 0.0 and _anim_lock_timer <= 0.0:
			_do_melee_attack(to_player)

	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.lerp(desired_horizontal, clampf(acceleration * delta, 0.0, 1.0))
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	move_and_slide()
	_update_animation_state(desired_horizontal.length())

func _acquire_player() -> void:
	var found: Node = get_tree().get_first_node_in_group("player")
	if found is Player:
		_player = found

func _setup_boss_visuals() -> void:
	if mesh_instance:
		mesh_instance.visible = false

	if boss_model_scene == null:
		if mesh_instance:
			mesh_instance.visible = true
		return

	var instance: Node = boss_model_scene.instantiate()
	if not (instance is Node3D):
		if instance:
			instance.queue_free()
		if mesh_instance:
			mesh_instance.visible = true
		return

	_visual_root = instance as Node3D
	_visual_root.name = "BossVisual"
	add_child(_visual_root)
	_visual_root.position = model_position
	_visual_root.scale = model_scale
	_visual_root.rotation_degrees = model_rotation_degrees

	_anim_player = _find_animation_player(_visual_root)
	_resolve_animations()

	if _anim_player == null and mesh_instance:
		mesh_instance.visible = true

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found:
			return found
	return null

func _resolve_animations() -> void:
	if _anim_player == null:
		return

	var names: PackedStringArray = _anim_player.get_animation_list()
	if names.is_empty():
		return

	for raw_name in names:
		var low: String = String(raw_name).to_lower()
		if _anim_idle == &"" and _matches_any(low, ["idle", "stand", "breath"]):
			_anim_idle = StringName(raw_name)
		if _anim_move == &"" and _matches_any(low, ["walk", "run", "move", "locomotion"]):
			_anim_move = StringName(raw_name)
		if _anim_attack_front == &"" and _matches_any(low, ["attack_front", "front_attack", "forward_attack", "bite", "slash", "claw", "attack"]):
			_anim_attack_front = StringName(raw_name)
		if _anim_attack_back == &"" and _matches_any(low, ["attack_back", "rear", "back", "behind", "tail"]):
			_anim_attack_back = StringName(raw_name)
		if _anim_hurt == &"" and _matches_any(low, ["hurt", "hit", "damage", "pain", "stagger"]):
			_anim_hurt = StringName(raw_name)
		if _anim_death == &"" and _matches_any(low, ["death", "die", "dead", "defeat"]):
			_anim_death = StringName(raw_name)

	var usable: Array[StringName] = []
	for raw_name in names:
		var anim_name: String = String(raw_name)
		if anim_name.to_upper() == "RESET":
			continue
		usable.append(StringName(raw_name))

	if usable.is_empty():
		usable.append(StringName(names[0]))

	if _anim_idle == &"":
		_anim_idle = usable[min(0, usable.size() - 1)]
	if _anim_move == &"":
		_anim_move = usable[min(1, usable.size() - 1)]
	if _anim_attack_front == &"":
		_anim_attack_front = usable[min(2, usable.size() - 1)]
	if _anim_attack_back == &"":
		_anim_attack_back = usable[min(3, usable.size() - 1)]
	if _anim_hurt == &"":
		_anim_hurt = usable[min(4, usable.size() - 1)]
	if _anim_death == &"":
		_anim_death = usable[usable.size() - 1]

	print("[Boss] Animations choisies:", {
		"idle": _anim_idle,
		"move": _anim_move,
		"attack_front": _anim_attack_front,
		"attack_back": _anim_attack_back,
		"hurt": _anim_hurt,
		"death": _anim_death
	})

func _matches_any(value: String, keywords: Array[String]) -> bool:
	for keyword in keywords:
		if value.contains(keyword):
			return true
	return false

func _update_animation_state(desired_speed: float) -> void:
	if _anim_player == null or _anim_lock_timer > 0.0 or _hurt_flash_timer > 0.0:
		return

	if desired_speed > 0.2:
		var spd: float = clampf(desired_speed / max(move_speed, 0.1), 0.85, 1.35)
		_play_anim(_anim_move, spd)
	else:
		_play_anim(_anim_idle, 1.0)

func _play_anim(anim_name: StringName, speed: float = 1.0, blend: float = 0.12) -> void:
	if _anim_player == null or anim_name == &"":
		return
	if not _anim_player.has_animation(String(anim_name)):
		return

	if _current_anim != anim_name:
		_anim_player.play(String(anim_name), blend, speed)
		_current_anim = anim_name
		_current_speed = speed
	elif absf(_current_speed - speed) > 0.04:
		_anim_player.speed_scale = speed
		_current_speed = speed

func _can_detect_player() -> bool:
	if _player == null:
		return false
	if aggro_immediately_on_spawn:
		return true
	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	return to_player.length() <= detection_range

func _look_at_direction(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.01:
		return
	var target_yaw: float = atan2(direction.x, direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 5.5 * delta)

func _is_player_in_front(to_player: Vector3) -> bool:
	if to_player.length() < 0.001:
		return true
	var forward: Vector3 = -global_transform.basis.z
	var alignment: float = forward.dot(to_player.normalized())
	return alignment >= 0.0

func _do_melee_attack(to_player: Vector3) -> void:
	_attack_timer = attack_cooldown

	if _is_player_in_front(to_player):
		_play_anim(_anim_attack_front, 1.08)
	else:
		_play_anim(_anim_attack_back, 1.08)

	_anim_lock_timer = maxf(0.62, melee_windup_time + 0.2)
	_deal_melee_damage_after_delay(melee_windup_time)

func _deal_melee_damage_after_delay(delay_sec: float) -> void:
	await get_tree().create_timer(maxf(0.01, delay_sec)).timeout
	if _is_dying:
		return
	if _player == null or not is_instance_valid(_player):
		return
	if not _player.has_method("take_damage"):
		return

	var to_player: Vector3 = _player.global_position - global_position
	to_player.y = 0.0
	var dist: float = to_player.length()
	if dist > attack_range * melee_hit_grace_range_multiplier:
		return

	_player.call("take_damage", melee_damage, global_position)
	call("_trigger_camera_shake", camera_shake_attack, 0.11)

func _on_timer_timeout() -> void:
	if _is_dying:
		return

	if not _can_detect_player():
		_schedule_next_projectile_volley()
		return

	var volley_count: int = _get_projectiles_this_volley()
	shoot_projectiles(volley_count)
	_play_anim(_anim_attack_front, 1.0)
	_anim_lock_timer = maxf(_anim_lock_timer, 0.35)

	_schedule_next_projectile_volley()

func shoot_projectiles(projectile_count: int) -> void:
	if projectile_scene == null:
		return

	var half_x: float = maxf(2.0, arena_half_extent_x - projectile_edge_margin)
	var half_z: float = maxf(2.0, arena_half_extent_z - projectile_edge_margin)
	var safe_count: int = maxi(1, projectile_count)

	# 1) Pluie random sur toute l'arène
	for i in range(safe_count):
		var px: float = arena_center.x + _rng.randf_range(-half_x, half_x)
		var pz: float = arena_center.z + _rng.randf_range(-half_z, half_z)
		_spawn_projectile_at_xz(px, pz)

	# 2) Salve ciblée autour du joueur (évitable, mais dangereuse)
	if not targeted_salvo_enabled:
		return
	if _player == null or not is_instance_valid(_player):
		return

	var targeted_count: int = _get_targeted_projectiles_this_volley()
	if targeted_count <= 0:
		return

	var player_pos: Vector3 = _player.global_position
	var radius: float = _get_targeted_radius()
	var angle_offset: float = _rng.randf_range(0.0, TAU)

	for i in range(targeted_count):
		var use_center_strike: bool = _rng.randf() < targeted_center_strikes_chance
		var target_x: float = player_pos.x
		var target_z: float = player_pos.z

		if not use_center_strike:
			var t: float = float(i) / maxf(float(targeted_count), 1.0)
			var angle: float = angle_offset + t * TAU
			var ring_radius: float = radius + _rng.randf_range(-targeted_ring_jitter, targeted_ring_jitter)
			target_x += cos(angle) * ring_radius
			target_z += sin(angle) * ring_radius
		else:
			target_x += _rng.randf_range(-1.2, 1.2)
			target_z += _rng.randf_range(-1.2, 1.2)

		var clamped: Vector2 = _clamp_to_arena_xz(target_x, target_z)
		_spawn_projectile_at_xz(clamped.x, clamped.y)

func _spawn_projectile_at_xz(x: float, z: float) -> void:
	if projectile_scene == null:
		return
	if get_parent() == null:
		return

	var proj: Node3D = projectile_scene.instantiate() as Node3D
	if proj == null:
		return
	get_parent().add_child(proj)

	var py: float = arena_center.y + projectile_spawn_height
	proj.global_position = Vector3(x, py, z)

func _clamp_to_arena_xz(x: float, z: float) -> Vector2:
	var half_x: float = maxf(2.0, arena_half_extent_x - projectile_edge_margin)
	var half_z: float = maxf(2.0, arena_half_extent_z - projectile_edge_margin)
	var clamped_x: float = clampf(x, arena_center.x - half_x, arena_center.x + half_x)
	var clamped_z: float = clampf(z, arena_center.z - half_z, arena_center.z + half_z)
	return Vector2(clamped_x, clamped_z)

func is_vulnerable_to_damage_type(type: String) -> bool:
	if type == "flame":
		return current_phase == Phase.PHASE2
	if type == "charge":
		return current_phase == Phase.PHASE3
	return false

func take_damage(type: String) -> bool:
	if _is_dying:
		return false
	if not is_vulnerable_to_damage_type(type):
		return false

	var damage: float = 0.0
	if current_phase == Phase.PHASE2 and type == "flame":
		damage = phase2_flame_damage
	elif current_phase == Phase.PHASE3 and type == "charge":
		damage = phase3_charge_damage

	if damage <= 0.0:
		return false

	health = maxf(0.0, health - damage)
	health_changed.emit(health, max_health)
	_play_anim(_anim_hurt, 1.0)
	_hurt_flash_timer = 0.28
	_anim_lock_timer = maxf(_anim_lock_timer, 0.2)
	call("_trigger_camera_shake", camera_shake_hurt, 0.09)

	if current_phase == Phase.PHASE2 and health <= 30.0:
		current_phase = Phase.PHASE3
		phase_changed.emit(current_phase, get_phase_display_text(current_phase))
		print("Boss -> PHASE 3 (vulnerable charge)")

	if health <= 0.0:
		die()

	return true

func _update_phase1_survival(delta: float) -> void:
	if current_phase != Phase.PHASE1:
		return
	if _is_dying:
		return

	_phase1_elapsed = minf(phase1_survival_duration, _phase1_elapsed + maxf(0.0, delta))
	phase1_timer_changed.emit(get_phase1_time_remaining(), phase1_survival_duration)

	if _phase1_elapsed >= phase1_survival_duration:
		current_phase = Phase.PHASE2
		phase_changed.emit(current_phase, get_phase_display_text(current_phase))
		print("Boss -> PHASE 2 (timer survie terminé, vulnérable feu)")

func get_phase1_time_remaining() -> float:
	return maxf(0.0, phase1_survival_duration - _phase1_elapsed)

func get_phase_display_text(phase: int = -1) -> String:
	var p: int = phase
	if p < 0:
		p = int(current_phase)
	match p:
		Phase.PHASE1:
			return "PHASE 1 - Résiste au feu et à la charge"
		Phase.PHASE2:
			return "PHASE 2 - Vulnérable au feu"
		Phase.PHASE3:
			return "PHASE 3 - Vulnérable à la charge"
		_:
			return "PHASE ?"

func _health_ratio() -> float:
	return clampf(health / maxf(max_health, 1.0), 0.0, 1.0)

func _get_projectile_density_multiplier() -> float:
	match current_phase:
		Phase.PHASE2:
			return phase2_density_multiplier
		Phase.PHASE3:
			return phase3_density_multiplier
		_:
			return 1.0

func _get_projectiles_this_volley() -> int:
	var missing_health: float = 1.0 - _health_ratio()
	var base_count: float = lerpf(float(projectiles_min_per_volley), float(projectiles_max_per_volley), missing_health)
	var multiplied: float = base_count * _get_projectile_density_multiplier()
	return clampi(roundi(multiplied), 6, 64)

func _get_targeted_projectiles_this_volley() -> int:
	var missing_health: float = 1.0 - _health_ratio()
	var base_count: float = lerpf(float(targeted_projectiles_min_per_volley), float(targeted_projectiles_max_per_volley), missing_health)
	var multiplied: float = base_count * _get_projectile_density_multiplier()
	return clampi(roundi(multiplied), 0, 36)

func _get_targeted_radius() -> float:
	var missing_health: float = 1.0 - _health_ratio()
	# Plus le boss est low HP, plus la salve se resserre autour du joueur.
	return clampf(lerpf(targeted_radius_max, targeted_radius_min, missing_health), 1.2, 32.0)

func _get_projectile_interval() -> float:
	var missing_health: float = 1.0 - _health_ratio()
	var base_interval: float = lerpf(projectile_interval_max, projectile_interval_min, missing_health)
	var phase_mul: float = _get_projectile_density_multiplier()
	return clampf(base_interval / maxf(phase_mul, 0.01), 0.35, 3.0)

func _schedule_next_projectile_volley() -> void:
	if timer == null:
		return
	timer.wait_time = _get_projectile_interval()
	timer.start()

func _get_phase_speed_multiplier() -> float:
	match current_phase:
		Phase.PHASE1:
			return 0.92
		Phase.PHASE2:
			return 1.0
		Phase.PHASE3:
			return 1.12
		_:
			return 1.0

func _trigger_camera_shake(intensity: float, duration: float) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null or not cam.is_inside_tree():
		return

	if _camera_shake_tween and _camera_shake_tween.is_valid():
		_camera_shake_tween.kill()

	var x: float = _rng.randf_range(-intensity, intensity)
	var y: float = _rng.randf_range(-intensity * 0.75, intensity * 0.75)

	_camera_shake_tween = create_tween()
	_camera_shake_tween.set_trans(Tween.TRANS_SINE)
	_camera_shake_tween.set_ease(Tween.EASE_OUT)
	_camera_shake_tween.tween_property(cam, "h_offset", x, duration * 0.35)
	_camera_shake_tween.parallel().tween_property(cam, "v_offset", y, duration * 0.35)
	_camera_shake_tween.tween_property(cam, "h_offset", 0.0, duration * 0.65)
	_camera_shake_tween.parallel().tween_property(cam, "v_offset", 0.0, duration * 0.65)

func die() -> void:
	if _is_dying:
		return
	_is_dying = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	if collision_shape:
		collision_shape.disabled = true

	health = 0.0
	health_changed.emit(health, max_health)
	boss_defeated.emit()
	print("Boss defeated!")
	call("_trigger_camera_shake", camera_shake_death, 0.2)

	if _anim_player and _anim_death != &"" and _anim_player.has_animation(String(_anim_death)):
		_play_anim(_anim_death, 1.0, 0.08)
		var death_len: float = _anim_player.get_animation(String(_anim_death)).length
		await get_tree().create_timer(clampf(death_len, 0.8, 3.0)).timeout
	queue_free()
