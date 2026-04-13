extends Area3D

@export var speed: float = 10.0
@export var impact_enabled: bool = true
@export var impact_duration: float = 0.28
@export var impact_flash_scale: float = 2.8
@export var impact_wave_scale: float = 4.2
@export var impact_light_energy: float = 3.0

# Marque de brûlure temporaire (anti-feu infini)
@export var burn_mark_enabled: bool = true
@export var burn_mark_lifetime: float = 2.6
@export var burn_mark_start_scale: float = 1.6
@export var burn_mark_end_scale: float = 2.8

# Son d'impact (optionnel)
@export var impact_sfx: AudioStream
@export var impact_sfx_volume_db: float = -5.0

var direction: Vector3 = Vector3.DOWN

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	if position.y < -50.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body is Enemy:
		return

	if impact_enabled:
		_spawn_impact_effect()

	if body is Player:
		print("Player hit!")
		if body.has_method("take_damage"):
			body.call("take_damage", 1, global_position)
		else:
			Global.respawn_player(body)
		queue_free()
		return

	queue_free()

func _spawn_impact_effect() -> void:
	var impact_pos: Vector3 = _get_ground_impact_position()
	var root: Node3D = Node3D.new()
	root.name = "FireballImpactFX"

	var parent_for_fx: Node = get_tree().current_scene
	if parent_for_fx == null:
		parent_for_fx = get_parent()
	if parent_for_fx == null:
		return
	parent_for_fx.add_child(root)
	root.global_position = impact_pos + Vector3.UP * 0.05

	# Auto cleanup GARANTI (même si le projectile est déjà détruit)
	var cleanup_timer: Timer = Timer.new()
	cleanup_timer.one_shot = true
	cleanup_timer.wait_time = max(impact_duration + 0.1, burn_mark_lifetime + 0.15)
	root.add_child(cleanup_timer)
	cleanup_timer.timeout.connect(root.queue_free)
	cleanup_timer.start()

	# Flash central
	var flash: MeshInstance3D = MeshInstance3D.new()
	var flash_mesh: SphereMesh = SphereMesh.new()
	flash_mesh.radius = 0.35
	flash_mesh.height = 0.7
	flash.mesh = flash_mesh
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.transparency = 0.0
	flash.material_override = _make_impact_material(Color(1.0, 0.45, 0.1, 0.9), true)
	flash.scale = Vector3.ONE * 0.2
	root.add_child(flash)

	# Onde de choc au sol
	var wave: MeshInstance3D = MeshInstance3D.new()
	var wave_mesh: CylinderMesh = CylinderMesh.new()
	wave_mesh.top_radius = 0.6
	wave_mesh.bottom_radius = 0.6
	wave_mesh.height = 0.03
	wave.mesh = wave_mesh
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.transparency = 0.0
	wave.material_override = _make_impact_material(Color(1.0, 0.25, 0.05, 0.85), false)
	wave.position = Vector3(0.0, 0.02, 0.0)
	wave.scale = Vector3(0.2, 1.0, 0.2)
	root.add_child(wave)

	# Marque de brûlure au sol (temporaire)
	if burn_mark_enabled:
		var scorch: MeshInstance3D = MeshInstance3D.new()
		var scorch_mesh: CylinderMesh = CylinderMesh.new()
		scorch_mesh.top_radius = 0.85
		scorch_mesh.bottom_radius = 0.85
		scorch_mesh.height = 0.01
		scorch.mesh = scorch_mesh
		scorch.position = Vector3(0.0, 0.005, 0.0)
		scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scorch.transparency = 0.25
		scorch.scale = Vector3.ONE * burn_mark_start_scale
		scorch.material_override = _make_scorch_material()
		root.add_child(scorch)

		var scorch_tw: Tween = root.create_tween()
		scorch_tw.set_trans(Tween.TRANS_SINE)
		scorch_tw.set_ease(Tween.EASE_OUT)
		scorch_tw.parallel().tween_property(scorch, "scale", Vector3.ONE * burn_mark_end_scale, burn_mark_lifetime)
		scorch_tw.parallel().tween_property(scorch, "transparency", 1.0, burn_mark_lifetime)

	# Flash de lumière
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.15)
	light.omni_range = 8.5
	light.light_energy = impact_light_energy
	root.add_child(light)

	# Son d'impact optionnel
	if impact_sfx != null:
		var sfx: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		sfx.stream = impact_sfx
		sfx.volume_db = impact_sfx_volume_db
		sfx.max_distance = 40.0
		sfx.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		root.add_child(sfx)
		sfx.play()

	var tw: Tween = root.create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "scale", Vector3.ONE * impact_flash_scale, impact_duration)
	tw.parallel().tween_property(flash, "transparency", 1.0, impact_duration)
	tw.parallel().tween_property(wave, "scale", Vector3(impact_wave_scale, 1.0, impact_wave_scale), impact_duration)
	tw.parallel().tween_property(wave, "transparency", 1.0, impact_duration)
	tw.parallel().tween_property(light, "light_energy", 0.0, impact_duration)

func _make_impact_material(col: Color, additive: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.no_depth_test = true
	return mat

func _make_scorch_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.05, 0.03, 0.02, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.22, 0.08, 0.03, 0.55)
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _get_ground_impact_position() -> Vector3:
	var from: Vector3 = global_position + Vector3.UP * 0.8
	var to: Vector3 = global_position + Vector3.DOWN * 7.5
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		return hit["position"]
	return global_position
