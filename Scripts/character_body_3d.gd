extends CharacterBody3D

class_name Player

# --- CONFIGURATION ---
@export var walk_speed: float = 5.0
@export var run_speed: float = 10.0
@export var charge_speed: float = 18.0
@export var jump_force: float = 15.0  # Increased to give more time for glide
@export var gravity: float = 30.0

@export var glide_gravity: float = 9.0
@export var glide_forward_speed: float = 12.0
@export var glide_rise_speed: float = 4.8
@export var glide_vertical_accel: float = 9.5
@export var glide_fall_speed: float = 8.5
@export var fast_fall_threshold: float = -8.0
@export var glide_pitch_max_up_deg: float = 32.0
@export var glide_pitch_max_down_deg: float = 36.0
@export var glide_pitch_smoothing: float = 10.0
@export var glide_pitch_speed_for_max: float = 5.5
@export_enum("X", "Z") var glide_pitch_axis: String = "X"

# Animation mapping - CORRECTED based on actual animations
# _Action Stash] = Idle (generic idle)
# _Action Stash]_001 = Cracher une boule de feu (Spit fireball) - FLAME ATTACK
# _Action Stash]_002 = Cracher une boule de feu but incomplete (alt flame)
# _Action Stash]_003 = Attaque mêlée (clic droit)
# _Action Stash]_004 = Animation contente (Happy) - ALT IDLE
# _Action Stash]_005 = Regarder autour (Look around) - ALT IDLE
# _Action Stash]_006 = S'assoir et faire toilette (Sit/groom) - ALT IDLE
# _Action Stash]_007 = Remuer la queue (Wag tail) - ALT IDLE
# _Action Stash]_008 = Eternuer (Sneeze) - ALT IDLE
# _Action Stash]_009 = Sprint en vol (air sprint)
# _Action Stash]_010 = Animation du vol en elle-même (Flight loop) - GLIDE LOOP
# _Action Stash]_011 = Chute de haut (high fall)
# _Action Stash]_012 = Trottiner (Trot) - WALK
# _Action Stash]_013 = Atterir du vol (Landing) - LANDING
# _Action Stash]_014 = Nager (Swimming)

@export var idle_animation_name: String = "_Action Stash]_004"  # Animation contente (Happy idle)
@export var walk_animation_name: String = "_Action Stash]_012"  # Trot/Walk
@export var run_animation_name: String = "_Action Stash]"  # Run/Course - MAIN RUN ANIMATION
@export var jump_animation_name: String = "_Action Stash]_010"  # Jump in air (no roll)
@export var right_click_attack_animation_name: String = "_Action Stash]_003"  # Melee attack on right click
@export var glide_animation_name: String = "_Action Stash]_010"  # Flight loop while gliding
@export var glide_sprint_animation_name: String = "_Action Stash]_009"  # Air sprint while gliding
@export var fall_animation_name: String = "_Action Stash]_011"  # High fall animation
@export var rest_animation_name: String = "_Action Stash]_005"  # Short idle when stopping movement
@export var charge_animation_name: String = "_Action Stash]"  # Charge/Run - use same as run_animation
@export var flame_animation_name: String = "_Action Stash]_001"  # Cracher boule de feu - FLAME ATTACK
@export var landing_animation_name: String = "_Action Stash]_013"  # Landing from flight

# --- STATES ---
enum State { GROUNDED, JUMPING, GLIDING, CHARGING, FLAMING, ATTACKING, LANDING }
var current_state: State = State.GROUNDED
var was_gliding: bool = false  # Track if we just finished gliding

# --- VARIABLES ---
var can_glide: bool = false
var flame_timer: float = 0.0
const FLAME_DURATION: float = 0.6

@export var right_click_attack_duration: float = 0.24
@export var right_click_attack_cooldown: float = 0.10
@export var right_click_attack_dash_speed: float = 12.5
@export var right_click_attack_anim_speed: float = 1.55
var right_click_attack_timer: float = 0.0
var _last_right_click_attack_time: float = -10.0
var right_click_attack_direction: Vector3 = Vector3.ZERO

var last_glide_jump_tap_time: float = -10.0
const GLIDE_DOUBLE_TAP_WINDOW: float = 0.3

var max_stamina: float = 100.0
var current_stamina: float = 100.0
const STAMINA_DRAIN_CHARGE: float = 40.0
const STAMINA_REGEN: float = 20.0
@export var charge_resume_stamina_threshold: float = 8.0
@export var charge_start_stamina_threshold: float = 8.0
var charge_exhausted: bool = false

# Idle timer - only play idle animation after being still for a moment
var idle_timer: float = 0.0
const IDLE_DELAY: float = 6.0

@onready var pivot: Node3D = $Pivot_Modele
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var endurance_bar: ProgressBar = %EnduranceBar
@onready var health_bar: ProgressBar = %HealthBar
@onready var flame_area: Area3D = $Pivot_Modele/FlameArea

@export var fireball_scene: PackedScene = preload("res://Scenes/PlayerFireball.tscn")
@export var fireball_speed: float = 46.0
@export var fireball_cooldown: float = 0.16
@export var fireball_spawn_forward: float = 1.8
@export var fireball_spawn_height: float = 1.0
var _last_fireball_time: float = -10.0

var anim_player: AnimationPlayer

var available_animations: Array[String] = []
var current_animation: String = ""

@export var void_fall_y: float = -80.0
@export var respawn_on_void: bool = true
var spawn_position: Vector3 = Vector3.ZERO

@export var max_health: int = 5
var current_health: int = 5
@export var damage_invulnerability_time: float = 0.7
var _damage_invulnerability_timer: float = 0.0

const FIRE_IMMUNE_HINT_TEXT: String = "Cet ennemi n'est pas vulnérable au feu !"
const FIRE_IMMUNE_HINT_COOLDOWN: float = 0.9
var _last_fire_immune_hint_time: float = -10.0
var _combat_hint_layer: CanvasLayer
var _combat_hint_label: Label
var _combat_hint_tween: Tween

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")
	_ensure_combat_hint_ui()
	spawn_position = global_position
	_ensure_fly_down_action()
	_remove_ctrl_from_flame_binding()
	_ensure_flame_mouse_binding()
	_ensure_right_attack_mouse_binding()
	# Improve grounding on thin platforms
	floor_snap_length = 0.35
	safe_margin = 0.08
	anim_player = pivot.get_node_or_null("Sketchfab_Scene/AnimationPlayer")
	
	# Debug: print available animations
	if anim_player:
		print("AnimationPlayer found!")
		var anim_list = anim_player.get_animation_list()
		print("Available animations: ", anim_list)
		for anim_name in anim_list:
			print("  - " + anim_name)
	else:
		print("ERROR: AnimationPlayer not found at path!")
		print("Available children of Pivot_Modele:")
		for child in pivot.get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
			if child.name == "Sketchfab_Scene":
				for subchild in child.get_children():
					print("	- ", subchild.name, " (", subchild.get_class(), ")")
	
	if endurance_bar:
		endurance_bar.max_value = max_stamina
		endurance_bar.value = current_stamina

	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true
	
	# Print animation configuration
	print("\n=== ANIMATION CONFIGURATION ===")
	print("✓ Idle: ", idle_animation_name)
	print("✓ Walk: ", walk_animation_name)
	print("✓ Run: ", run_animation_name)
	print("✓ Jump: ", jump_animation_name)
	print("✓ RightAttack: ", right_click_attack_animation_name)
	print("✓ Glide: ", glide_animation_name)
	print("✓ Rest: ", rest_animation_name)
	print("✓ Charge: ", charge_animation_name)
	print("✓ Flame: ", flame_animation_name)
	print("✓ Landing: ", landing_animation_name)
	print("================================\n")
	
	# Force loop for locomotion animations to avoid freeze
	_set_animation_loop(walk_animation_name, true)
	_set_animation_loop(run_animation_name, true)
	_set_animation_loop(glide_animation_name, true)
	_set_animation_loop(glide_sprint_animation_name, true)
	_set_animation_loop(fall_animation_name, true)
	_set_animation_loop(charge_animation_name, true)
	_set_animation_loop(rest_animation_name, true)
	_set_animation_loop(idle_animation_name, true)

func _set_animation_loop(anim_name: String, should_loop: bool) -> void:
	if not anim_player:
		return
	if not anim_player.has_animation(anim_name):
		return
	var anim_res: Animation = anim_player.get_animation(anim_name)
	if anim_res:
		anim_res.loop_mode = Animation.LOOP_LINEAR if should_loop else Animation.LOOP_NONE

func _ensure_fly_down_action() -> void:
	if not InputMap.has_action("fly_down"):
		InputMap.add_action("fly_down")

	# Remove old C binding to avoid confusion
	for event in InputMap.action_get_events("fly_down"):
		if event is InputEventKey and event.keycode == KEY_C:
			InputMap.action_erase_event("fly_down", event)

	var has_ctrl: bool = false
	for event in InputMap.action_get_events("fly_down"):
		if event is InputEventKey and event.keycode == KEY_CTRL:
			has_ctrl = true
			break

	if not has_ctrl:
		var ctrl_event: InputEventKey = InputEventKey.new()
		ctrl_event.keycode = KEY_CTRL
		InputMap.action_add_event("fly_down", ctrl_event)

func _remove_ctrl_from_flame_binding() -> void:
	if not InputMap.has_action("flame"):
		return

	for event in InputMap.action_get_events("flame"):
		if event is InputEventKey and event.keycode == KEY_CTRL:
			InputMap.action_erase_event("flame", event)

func _ensure_flame_mouse_binding() -> void:
	if not InputMap.has_action("flame"):
		InputMap.add_action("flame")

	var has_left_click: bool = false
	for event in InputMap.action_get_events("flame"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_left_click = true
			break

	if not has_left_click:
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("flame", mouse_event)

func _ensure_right_attack_mouse_binding() -> void:
	if not InputMap.has_action("right_attack"):
		InputMap.add_action("right_attack")

	var has_right_click: bool = false
	for event in InputMap.action_get_events("right_attack"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			has_right_click = true
			break

	if not has_right_click:
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("right_attack", mouse_event)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		spring_arm.rotate_y(-event.relative.x * 0.005)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * 0.005, -1.2, 0.5)

	if event.is_action_pressed("right_attack"):
		trigger_right_click_attack()

	if event.is_action_pressed("flame") and current_state != State.CHARGING and current_state != State.ATTACKING:
		trigger_flame_attack()

func _physics_process(delta: float) -> void:
	if _damage_invulnerability_timer > 0.0:
		_damage_invulnerability_timer -= delta

	handle_stamina(delta)
	_update_right_click_attack(delta)
	
	var jumped_this_frame: bool = false
	
	# Jump / Glide input
	if Input.is_action_just_pressed("jump"):
		if is_on_floor() and current_state != State.CHARGING and current_state != State.ATTACKING:
			velocity.y = jump_force
			current_state = State.JUMPING
			jumped_this_frame = true
			var safe_jump_anim: String = jump_animation_name
			if safe_jump_anim == right_click_attack_animation_name:
				safe_jump_anim = "_Action Stash]_010"
			if anim_player and anim_player.has_animation(safe_jump_anim):
				anim_player.play(safe_jump_anim)
			print("[JUMP] Floor -> JUMPING")
		elif not is_on_floor() and current_state == State.GLIDING:
			var now_sec: float = Time.get_ticks_msec() / 1000.0
			if now_sec - last_glide_jump_tap_time <= GLIDE_DOUBLE_TAP_WINDOW:
				current_state = State.JUMPING
				last_glide_jump_tap_time = -10.0
				print("[JUMP] GLIDING double tap -> JUMPING")
			else:
				last_glide_jump_tap_time = now_sec
		elif not is_on_floor() and current_state != State.CHARGING and current_state != State.FLAMING and current_state != State.ATTACKING:
			# Toggle on gliding
			start_gliding()
			if anim_player and anim_player.has_animation(glide_animation_name):
				anim_player.play(glide_animation_name)
			print("[JUMP] Air -> GLIDING")
	
	handle_movement(delta)
	move_and_slide()
	update_state_after_motion(jumped_this_frame)
	update_animations()
	
	# Void handling: respawn instead of clamping to an invisible floor
	if global_position.y < void_fall_y:
		if respawn_on_void:
			global_position = spawn_position
			velocity = Vector3.ZERO
			current_state = State.GROUNDED
		else:
			queue_free()
	
	handle_collisions()
	
	if endurance_bar:
		endurance_bar.value = current_stamina
		endurance_bar.visible = current_stamina < max_stamina

func handle_collisions() -> void:
	# Charge collision
	if current_state == State.CHARGING:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider.has_method("take_damage"):
				collider.take_damage("charge")
	
	# Flame collision (active only when flaming)
	if current_state == State.FLAMING:
		var bodies = flame_area.get_overlapping_bodies()
		for body in bodies:
			if body.has_method("take_damage") and body != self:
				if _is_target_vulnerable_to(body, "flame"):
					body.take_damage("flame")
				else:
					show_fire_immune_hint()

	# Right-click melee collision
	if current_state == State.ATTACKING:
		var melee_bodies = flame_area.get_overlapping_bodies()
		for body in melee_bodies:
			if body.has_method("take_damage") and body != self:
				body.take_damage("melee")


func _is_target_vulnerable_to(target: Object, damage_type: String) -> bool:
	if target == null:
		return false
	if target.has_method("is_vulnerable_to_damage_type"):
		return bool(target.call("is_vulnerable_to_damage_type", damage_type))
	return true

func show_fire_immune_hint() -> void:
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	if now_sec - _last_fire_immune_hint_time < FIRE_IMMUNE_HINT_COOLDOWN:
		return
	_last_fire_immune_hint_time = now_sec
	_show_combat_hint(FIRE_IMMUNE_HINT_TEXT, Color(1.0, 0.55, 0.22, 1.0))

func _ensure_combat_hint_ui() -> void:
	if _combat_hint_layer != null:
		return

	_combat_hint_layer = CanvasLayer.new()
	_combat_hint_layer.name = "CombatHintLayer"
	_combat_hint_layer.layer = 25
	add_child(_combat_hint_layer)

	_combat_hint_label = Label.new()
	_combat_hint_label.name = "CombatHintLabel"
	_combat_hint_label.visible = false
	_combat_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combat_hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_combat_hint_label.offset_left = -360.0
	_combat_hint_label.offset_top = 96.0
	_combat_hint_label.offset_right = 360.0
	_combat_hint_label.offset_bottom = 150.0
	_combat_hint_label.add_theme_font_size_override("font_size", 30)
	_combat_hint_label.add_theme_color_override("font_outline_color", Color(0.06, 0.03, 0.08, 1.0))
	_combat_hint_label.add_theme_constant_override("outline_size", 6)
	_combat_hint_layer.add_child(_combat_hint_label)

func _show_combat_hint(message: String, tint: Color = Color(1.0, 1.0, 1.0, 1.0)) -> void:
	if _combat_hint_label == null:
		return

	if _combat_hint_tween and _combat_hint_tween.is_valid():
		_combat_hint_tween.kill()

	_combat_hint_label.text = message
	_combat_hint_label.visible = true
	_combat_hint_label.modulate = Color(tint.r, tint.g, tint.b, 0.0)
	_combat_hint_label.scale = Vector2(0.97, 0.97)

	_combat_hint_tween = create_tween()
	_combat_hint_tween.tween_property(_combat_hint_label, "modulate:a", 1.0, 0.12)
	_combat_hint_tween.parallel().tween_property(_combat_hint_label, "scale", Vector2.ONE, 0.12)
	_combat_hint_tween.tween_interval(0.65)
	_combat_hint_tween.tween_property(_combat_hint_label, "modulate:a", 0.0, 0.28)
	_combat_hint_tween.finished.connect(_on_combat_hint_finished)

func _on_combat_hint_finished() -> void:
	if _combat_hint_label:
		_combat_hint_label.visible = false

func handle_stamina(delta: float) -> void:
	if current_state == State.CHARGING:
		current_stamina -= STAMINA_DRAIN_CHARGE * delta
		if current_stamina <= 0.0:
			current_stamina = 0.0
			current_state = State.GROUNDED
			charge_exhausted = true
	else:
		current_stamina += STAMINA_REGEN * delta
		if charge_exhausted and current_stamina >= charge_resume_stamina_threshold:
			charge_exhausted = false
	
	current_stamina = clamp(current_stamina, 0.0, max_stamina)

func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = (spring_arm.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0.0
	direction = direction.normalized()

	# Charge state only on floor, with movement input and stamina lockout to avoid animation flicker
	var has_move_input: bool = input_dir.length() > 0.1
	var wants_charge: bool = Input.is_action_pressed("charge")
	var can_start_charge: bool = current_stamina >= charge_start_stamina_threshold and not charge_exhausted
	if current_state != State.ATTACKING and wants_charge and is_on_floor() and has_move_input and can_start_charge:
		current_state = State.CHARGING
	elif current_state == State.CHARGING and (not wants_charge or not has_move_input or not is_on_floor()):
		current_state = State.GROUNDED

	# Avoid floor snapping while rising (prevents jump state from being canceled)
	floor_snap_length = 0.0 if velocity.y > 0.0 else 0.35

	# Gravity / Vertical flight control
	if not is_on_floor():
		if current_state == State.GLIDING:
			var rise_pressed: bool = Input.is_action_pressed("jump")
			var down_pressed: bool = Input.is_action_pressed("fly_down")
			
			# Space held while gliding = rise
			if rise_pressed and not down_pressed:
				velocity.y = min(velocity.y + glide_vertical_accel * delta, glide_rise_speed)
			# Ctrl held while gliding = descend
			elif down_pressed and not rise_pressed:
				velocity.y = max(velocity.y - glide_vertical_accel * delta, -glide_fall_speed)
			# Neutral glide: keep altitude (no automatic fall)
			else:
				velocity.y = move_toward(velocity.y, 0.0, glide_vertical_accel * 1.2 * delta)
		else:
			velocity.y -= gravity * delta
			if velocity.y < -30.0:
				velocity.y = -30.0

	# Horizontal movement
	if current_state == State.ATTACKING:
		var attack_dir: Vector3 = right_click_attack_direction
		if attack_dir.length() < 0.01:
			attack_dir = -pivot.global_transform.basis.z
			attack_dir.y = 0.0
			attack_dir = attack_dir.normalized()
		velocity.x = lerp(velocity.x, attack_dir.x * right_click_attack_dash_speed, 16.0 * delta)
		velocity.z = lerp(velocity.z, attack_dir.z * right_click_attack_dash_speed, 16.0 * delta)
	elif current_state == State.CHARGING:
		var charge_dir: Vector3 = direction
		if charge_dir.length() < 0.01:
			charge_dir = -pivot.global_transform.basis.z
			charge_dir.y = 0.0
			charge_dir = charge_dir.normalized()
		velocity.x = lerp(velocity.x, charge_dir.x * charge_speed, 12.0 * delta)
		velocity.z = lerp(velocity.z, charge_dir.z * charge_speed, 12.0 * delta)
	elif current_state == State.GLIDING:
		# Glide movement only when player gives direction input (otherwise hover in place)
		if direction.length() > 0.01:
			velocity.x = lerp(velocity.x, direction.x * glide_forward_speed, 8.0 * delta)
			velocity.z = lerp(velocity.z, direction.z * glide_forward_speed, 8.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, glide_forward_speed * 8.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, glide_forward_speed * 8.0 * delta)
	else:
		if direction.length() > 0.01:
			var base_speed: float = run_speed if Input.is_action_pressed("charge") else walk_speed
			var target_vel: Vector3 = direction * base_speed
			velocity.x = lerp(velocity.x, target_vel.x, 10.0 * delta)
			velocity.z = lerp(velocity.z, target_vel.z, 10.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, walk_speed * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, walk_speed * 10.0 * delta)

	# Character facing (except while flaming)
	if current_state != State.FLAMING:
		var look_direction: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
		if look_direction.length() > 0.1:
			var target_rotation: float = atan2(look_direction.x, look_direction.z) + PI
			pivot.rotation.y = lerp_angle(pivot.rotation.y, target_rotation, 10.0 * delta)
		
		# Glide pitch: strong and readable based on input while moving forward
		var target_pitch: float = 0.0
		if current_state == State.GLIDING:
			var has_horizontal_input: bool = input_dir.length() > 0.1
			var rise_pressed: bool = Input.is_action_pressed("jump")
			var down_pressed: bool = Input.is_action_pressed("fly_down")
			
			if has_horizontal_input:
				if rise_pressed and not down_pressed:
					# Rising while gliding forward: nose up
					target_pitch = deg_to_rad(-glide_pitch_max_up_deg)
				elif down_pressed and not rise_pressed:
					# Descending while gliding forward: nose down
					target_pitch = deg_to_rad(glide_pitch_max_down_deg)
				else:
					# Small dynamic tilt when no vertical input
					var vertical_ratio: float = clamp(velocity.y / glide_pitch_speed_for_max, -1.0, 1.0)
					if vertical_ratio > 0.0:
						target_pitch = deg_to_rad(-glide_pitch_max_up_deg * 0.35 * vertical_ratio)
					elif vertical_ratio < 0.0:
						target_pitch = deg_to_rad(glide_pitch_max_down_deg * 0.35 * -vertical_ratio)
		
		if glide_pitch_axis == "Z":
			pivot.rotation.z = lerp_angle(pivot.rotation.z, target_pitch, glide_pitch_smoothing * delta)
			pivot.rotation.x = lerp_angle(pivot.rotation.x, 0.0, glide_pitch_smoothing * delta)
		else:
			pivot.rotation.x = lerp_angle(pivot.rotation.x, -target_pitch, glide_pitch_smoothing * delta)
			pivot.rotation.z = lerp_angle(pivot.rotation.z, 0.0, glide_pitch_smoothing * delta)

func update_state_after_motion(jumped_this_frame: bool) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		
		# Keep jump state on the exact frame we triggered jump
		if jumped_this_frame:
			return
		
		if current_state == State.GLIDING:
			current_state = State.LANDING
			was_gliding = false
			return
		
		if current_state == State.LANDING:
			current_state = State.GROUNDED
			return
		
		if current_state == State.JUMPING:
			current_state = State.GROUNDED
			return
		
		if current_state != State.CHARGING and current_state != State.FLAMING and current_state != State.ATTACKING:
			current_state = State.GROUNDED
	else:
		# If we are airborne, never stay GROUNDED/LANDING
		if current_state == State.GROUNDED or current_state == State.LANDING:
			current_state = State.JUMPING

func take_damage(amount: int = 1, _from_position: Vector3 = Vector3.ZERO) -> void:
	if _damage_invulnerability_timer > 0.0:
		return

	var dmg: int = maxi(amount, 1)
	current_health = max(0, current_health - dmg)
	_damage_invulnerability_timer = damage_invulnerability_time
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
		health_bar.visible = true
	print("[PLAYER] Damage: -", dmg, " | HP: ", current_health, "/", max_health)

	if current_health <= 0:
		current_health = max_health
		if health_bar:
			health_bar.max_value = max_health
			health_bar.value = current_health
			health_bar.visible = true
		Global.respawn_player(self)

func jump() -> void:
	velocity.y = jump_force
	current_state = State.JUMPING

func start_gliding() -> void:
	current_state = State.GLIDING
	was_gliding = true
	last_glide_jump_tap_time = -10.0
	# Prevent rocket-like climb when entering glide from a jump
	velocity.y = clamp(velocity.y, -1.0, 1.5)

func trigger_flame_attack() -> void:
	_shoot_fireball()

	# Important: tirer en l'air ne doit PAS casser le vol/glide.
	if not is_on_floor() or current_state == State.GLIDING or current_state == State.JUMPING:
		return

	if current_state != State.FLAMING:
		start_flame()

func trigger_right_click_attack() -> void:
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	if now_sec - _last_right_click_attack_time < right_click_attack_cooldown:
		return
	if current_state == State.CHARGING or current_state == State.FLAMING or current_state == State.LANDING:
		return

	# Roll-attack direction: movement input first, otherwise character forward
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction: Vector3 = (spring_arm.global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	move_direction.y = 0.0
	if move_direction.length() > 0.01:
		right_click_attack_direction = move_direction.normalized()
	else:
		right_click_attack_direction = -pivot.global_transform.basis.z
		right_click_attack_direction.y = 0.0
		right_click_attack_direction = right_click_attack_direction.normalized()

	_last_right_click_attack_time = now_sec
	current_state = State.ATTACKING

	var attack_duration: float = right_click_attack_duration
	var attack_playback_speed: float = max(0.1, right_click_attack_anim_speed)
	if anim_player and anim_player.has_animation(right_click_attack_animation_name):
		var attack_anim: Animation = anim_player.get_animation(right_click_attack_animation_name)
		if attack_anim:
			attack_duration = max(attack_duration, attack_anim.length / attack_playback_speed)
		anim_player.play(right_click_attack_animation_name, -1.0, attack_playback_speed)
		current_animation = right_click_attack_animation_name

	right_click_attack_timer = attack_duration
	flame_area.monitoring = true

func _update_right_click_attack(delta: float) -> void:
	if current_state != State.ATTACKING:
		return

	right_click_attack_timer -= delta
	if right_click_attack_timer <= 0.0:
		right_click_attack_timer = 0.0
		flame_area.monitoring = false
		right_click_attack_direction = Vector3.ZERO
		if is_on_floor():
			current_state = State.GROUNDED
		else:
			current_state = State.JUMPING

func _shoot_fireball() -> void:
	if fireball_scene == null:
		return

	var now_sec: float = Time.get_ticks_msec() / 1000.0
	if now_sec - _last_fireball_time < fireball_cooldown:
		return
	_last_fireball_time = now_sec

	var fireball: PlayerFireball = fireball_scene.instantiate() as PlayerFireball
	if fireball == null:
		return

	get_tree().current_scene.add_child(fireball)

	var forward: Vector3 = -pivot.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = -global_transform.basis.z
	forward = forward.normalized()

	fireball.global_position = global_position + Vector3.UP * fireball_spawn_height + forward * fireball_spawn_forward
	fireball.direction = forward
	fireball.speed = fireball_speed
	fireball.owner_node = self

func start_flame() -> void:
	if current_state == State.FLAMING:
		return
	
	current_state = State.FLAMING
	flame_timer = FLAME_DURATION
	flame_area.monitoring = true
	
	await get_tree().create_timer(FLAME_DURATION).timeout
	if current_state == State.FLAMING:
		current_state = State.GROUNDED
		flame_area.monitoring = false


func update_animations() -> void:
	if not anim_player:
		return

	var target_animation: String = ""
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var has_move_input: bool = input_dir.length() > 0.1

	match current_state:
		State.CHARGING:
			target_animation = run_animation_name
			idle_timer = 0.0
		State.FLAMING:
			target_animation = flame_animation_name
			idle_timer = 0.0
		State.ATTACKING:
			target_animation = right_click_attack_animation_name
			idle_timer = 0.0
		State.GLIDING:
			# In-air sprint only while moving in glide
			if not has_move_input:
				# User request: play high-fall anim while hovering (no movement input)
				target_animation = fall_animation_name
			elif Input.is_action_pressed("charge") and current_stamina > 0.0:
				target_animation = glide_sprint_animation_name
			else:
				target_animation = glide_animation_name
			idle_timer = 0.0
		State.JUMPING:
			# High-speed fall animation
			if velocity.y <= fast_fall_threshold:
				target_animation = fall_animation_name
			else:
				var safe_jump_anim: String = jump_animation_name
				if safe_jump_anim == right_click_attack_animation_name:
					safe_jump_anim = "_Action Stash]_010"
				target_animation = safe_jump_anim
			idle_timer = 0.0
		State.LANDING:
			target_animation = landing_animation_name
			idle_timer = 0.0
		State.GROUNDED:
			if has_move_input:
				# Normal move = trot, Shift/charge = run
				if Input.is_action_pressed("charge"):
					target_animation = run_animation_name
				else:
					target_animation = walk_animation_name
				idle_timer = 0.0
			else:
				idle_timer += get_physics_process_delta_time()
				if idle_timer >= IDLE_DELAY:
					target_animation = idle_animation_name
				else:
					target_animation = rest_animation_name

	# Fallback if chosen animation name doesn't exist
	if not anim_player.has_animation(target_animation):
		target_animation = "RESET" if anim_player.has_animation("RESET") else current_animation

	if target_animation == "":
		return

	# If same animation but player stopped it internally, restart it (prevents trot freeze)
	if target_animation == current_animation and not anim_player.is_playing():
		if current_state == State.ATTACKING:
			anim_player.play(target_animation, -1.0, max(0.1, right_click_attack_anim_speed))
		else:
			anim_player.play(target_animation)
		return

	if target_animation != current_animation:
		current_animation = target_animation
		if anim_player.has_animation(target_animation):
			if current_state == State.ATTACKING:
				anim_player.play(target_animation, -1.0, max(0.1, right_click_attack_anim_speed))
			else:
				anim_player.play(target_animation)
			print("ANIM CHANGE: ", target_animation, " (State: ", current_state, ")")
		else:
			print("WARNING: Animation '%s' not found!" % target_animation)
