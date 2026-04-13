extends Enemy
class_name EnemySpiderType

@export var spider_model: PackedScene = preload("res://Assets/spyro-the-dragon-reignited/spider-enemy/source/Attack.fbx")
@export var spider_scale: Vector3 = Vector3(200.0, 200.0, 200.0)
@export var spider_position: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var spider_rotation_degrees: Vector3 = Vector3(0.0, 0.0, 0.0)

var spider_root: Node3D
var spider_anim_player: AnimationPlayer
var spider_attack_anim: StringName = &""
var spider_move_anim: StringName = &""
var spider_idle_anim: StringName = &""
var current_spider_anim: StringName = &""

const SPIDER_BODY_MESH_PATH: String = "res://Assets/spyro-the-dragon-reignited/spider-enemy/source/Attack.fbx::ArrayMesh_pc5re"
const SPIDER_TEXTURE_DIR: String = "res://Assets/spyro-the-dragon-reignited/spider-enemy/textures/"

func _ready() -> void:
	max_health = 4
	health = max_health
	speed = 6.2
	acceleration = 15.0
	detection_range = 34.0
	attack_range = 3.2
	attack_cooldown = 0.75
	attack_damage = 1
	health_bar_height = 1.9
	health_bar_width = 1.6
	health_bar_thickness = 0.18
	body_color = Color(0.22, 0.65, 0.32, 1.0)
	body_scale = Vector3(0.9, 0.9, 0.9)
	super._ready()
	_setup_fallback_spider_mesh()
	_setup_spider_visual()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_spider_animation()

func _setup_fallback_spider_mesh() -> void:
	if mesh_instance == null:
		return
	var mesh_res: Resource = load(SPIDER_BODY_MESH_PATH)
	if mesh_res is Mesh:
		mesh_instance.mesh = mesh_res as Mesh
		mesh_instance.scale = Vector3(0.06, 0.06, 0.06)
		mesh_instance.position = Vector3(0.0, 0.25, 0.0)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.62, 0.28, 1.0)
		mat.roughness = 0.85
		mat.metallic = 0.0
		mesh_instance.material_override = mat
		mesh_instance.visible = true

func _setup_spider_visual() -> void:
	# Prefer model already present in scene for maximum reliability.
	if has_node("SpiderVisual"):
		spider_root = get_node("SpiderVisual") as Node3D
	elif spider_model != null:
		var inst: Node = spider_model.instantiate()
		if inst is Node3D:
			spider_root = inst as Node3D
			spider_root.name = "SpiderVisual"
			add_child(spider_root)

	if spider_root == null:
		push_warning("Spider model unavailable, keeping fallback body mesh visible.")
		return

	spider_root.position = spider_position
	spider_root.scale = spider_scale
	spider_root.rotation_degrees = spider_rotation_degrees

	# Ensure geometry is visible.
	_force_visible(spider_root)
	_apply_spider_materials()

	# Hide fallback mesh when the real spider model is available.
	if mesh_instance:
		mesh_instance.visible = false

	spider_anim_player = _find_animation_player(spider_root)
	_resolve_anims()
	_play_spider(spider_idle_anim if spider_idle_anim != &"" else spider_move_anim, 1.0)

func _force_visible(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visible = true
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node.mesh != null:
			# Keep imported materials/textures from FBX (don't override them).
			mesh_node.material_override = null
	for child in node.get_children():
		_force_visible(child)

func _apply_spider_materials() -> void:
	if spider_root == null:
		return

	var body_mesh: MeshInstance3D = _find_mesh_instance_by_name(spider_root, "spiderBody")
	var brain_mesh: MeshInstance3D = _find_mesh_instance_by_name(spider_root, "spiderBrain")
	var eyes_mesh: MeshInstance3D = _find_mesh_instance_by_name(spider_root, "eyes")

	if body_mesh:
		body_mesh.material_override = _build_spider_material(false)
	if brain_mesh:
		brain_mesh.material_override = _build_spider_material(true)
	if eyes_mesh:
		var eyes_mat: StandardMaterial3D = _build_spider_material(false)
		eyes_mat.emission_enabled = true
		eyes_mat.emission = Color(1.0, 0.25, 0.08, 1.0)
		eyes_mesh.material_override = eyes_mat

func _build_spider_material(is_brain: bool) -> StandardMaterial3D:
	var prefix: String = "T_spiderBrain" if is_brain else "T_spider"
	var albedo_tex: Texture2D = load(SPIDER_TEXTURE_DIR + prefix + "_A.png") as Texture2D
	var normal_tex: Texture2D = load(SPIDER_TEXTURE_DIR + prefix + "_N.png") as Texture2D
	var metallic_tex: Texture2D = load(SPIDER_TEXTURE_DIR + prefix + "_M.png") as Texture2D
	var roughness_tex: Texture2D = load(SPIDER_TEXTURE_DIR + prefix + "_R.png") as Texture2D
	var emission_tex: Texture2D = load(SPIDER_TEXTURE_DIR + prefix + "_E.png") as Texture2D

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.metallic = 0.35
	mat.roughness = 0.8

	if albedo_tex:
		mat.albedo_texture = albedo_tex
	if normal_tex:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
	if metallic_tex:
		mat.metallic_texture = metallic_tex
	if roughness_tex:
		mat.roughness_texture = roughness_tex
	if emission_tex:
		mat.emission_enabled = true
		mat.emission_texture = emission_tex
		mat.emission = Color(1.0, 1.0, 1.0, 1.0)

	return mat

func _find_mesh_instance_by_name(node: Node, target_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == target_name:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh_instance_by_name(child, target_name)
		if found:
			return found
	return null

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var ap: AnimationPlayer = _find_animation_player(child)
		if ap:
			return ap
	return null

func _resolve_anims() -> void:
	if spider_anim_player == null:
		return
	var list: PackedStringArray = spider_anim_player.get_animation_list()
	for anim_name in list:
		var lower: String = String(anim_name).to_lower()
		if spider_attack_anim == &"" and lower.contains("attack"):
			spider_attack_anim = StringName(anim_name)
		if spider_move_anim == &"" and (lower.contains("walk") or lower.contains("run") or lower.contains("move")):
			spider_move_anim = StringName(anim_name)
		if spider_idle_anim == &"" and lower.contains("idle"):
			spider_idle_anim = StringName(anim_name)
	if list.size() > 0 and spider_attack_anim == &"":
		spider_attack_anim = StringName(list[0])
	if spider_move_anim == &"":
		spider_move_anim = spider_attack_anim
	if spider_idle_anim == &"":
		spider_idle_anim = spider_move_anim

func _update_spider_animation() -> void:
	if spider_anim_player == null:
		return
	if _attack_timer > 0.58:
		_play_spider(spider_attack_anim, 1.25)
		return
	var hs: float = Vector2(velocity.x, velocity.z).length()
	if hs > 0.2:
		_play_spider(spider_move_anim, 1.1)
	else:
		_play_spider(spider_idle_anim, 0.9)

func _play_spider(anim_name: StringName, speed_scale: float = 1.0) -> void:
	if spider_anim_player == null or anim_name == &"":
		return
	if not spider_anim_player.has_animation(String(anim_name)):
		return

	var is_same_anim: bool = current_spider_anim == anim_name
	var is_current_on_player: bool = StringName(spider_anim_player.current_animation) == anim_name
	var should_restart: bool = (not is_same_anim) or (not is_current_on_player) or (not spider_anim_player.is_playing())

	if should_restart:
		spider_anim_player.play(String(anim_name), 0.12, speed_scale)
		current_spider_anim = anim_name
	else:
		spider_anim_player.speed_scale = speed_scale
