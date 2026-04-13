extends Area3D
class_name LevelPortal

@export_file("*.tscn") var target_scene: String
@export var portal_title: String = "Portail"
@export var gems_required: int = 0
@export var required_levels: Array[String] = []
@export var complete_level_on_enter: String = ""

@onready var visual_root: Node3D = $VisualRoot
@onready var portal_ring: MeshInstance3D = $VisualRoot/PortalRing
@onready var portal_core: MeshInstance3D = $VisualRoot/PortalCore
@onready var portal_light: OmniLight3D = $VisualRoot/PortalLight
@onready var title_label: Label3D = $VisualRoot/TitleLabel
@onready var requirement_label: Label3D = $VisualRoot/RequirementLabel

var _base_visual_y: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if Global.gems_changed.is_connected(_on_requirements_changed) == false:
		Global.gems_changed.connect(_on_requirements_changed)
	if Global.level_completed.is_connected(_on_level_completed) == false:
		Global.level_completed.connect(_on_level_completed)

	_base_visual_y = visual_root.position.y
	_duplicate_portal_materials()
	_refresh_visual_state()

func _exit_tree() -> void:
	if Global.gems_changed.is_connected(_on_requirements_changed):
		Global.gems_changed.disconnect(_on_requirements_changed)
	if Global.level_completed.is_connected(_on_level_completed):
		Global.level_completed.disconnect(_on_level_completed)

func _process(delta: float) -> void:
	portal_ring.rotate_y(delta * 1.25)

	var bob_time: float = Time.get_ticks_msec() * 0.0018
	visual_root.position.y = _base_visual_y + sin(bob_time) * 0.08

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		title_label.look_at(cam.global_position, Vector3.UP)
		requirement_label.look_at(cam.global_position, Vector3.UP)
		# Label3D can face backwards depending on mesh forward axis.
		title_label.rotate_y(PI)
		requirement_label.rotate_y(PI)

func _on_body_entered(body: Node) -> void:
	if not body is Player:
		return

	if not complete_level_on_enter.is_empty():
		Global.mark_level_completed(complete_level_on_enter)

	if not _can_enter_portal():
		_print_missing_requirements()
		return

	if target_scene.is_empty():
		push_warning("[Portal] target_scene est vide.")
		return

	get_tree().call_deferred("change_scene_to_file", target_scene)

func _on_requirements_changed(_new_amount: int) -> void:
	_refresh_visual_state()

func _on_level_completed(_level_id: String) -> void:
	_refresh_visual_state()

func _can_enter_portal() -> bool:
	if Global.total_gems < gems_required:
		return false
	if not Global.has_completed_all(required_levels):
		return false
	return true

func _refresh_visual_state() -> void:
	var is_open: bool = _can_enter_portal()
	title_label.text = portal_title
	requirement_label.text = _build_requirement_text(is_open)

	var open_color: Color = Color(0.42, 0.9, 1.0, 1.0)
	var locked_color: Color = Color(0.85, 0.34, 0.28, 1.0)
	var state_color: Color = open_color if is_open else locked_color

	title_label.modulate = Color(1.0, 0.97, 0.7, 1.0) if is_open else Color(1.0, 0.8, 0.8, 1.0)
	requirement_label.modulate = state_color
	portal_light.light_color = state_color
	portal_light.light_energy = 1.45 if is_open else 0.9

	var core_mat: StandardMaterial3D = portal_core.material_override as StandardMaterial3D
	if core_mat:
		core_mat.albedo_color = Color(state_color.r, state_color.g, state_color.b, 0.35)
		core_mat.emission = state_color

func _build_requirement_text(is_open: bool) -> String:
	if is_open:
		return "OUVERT - Entrer"

	var parts: Array[String] = []
	if Global.total_gems < gems_required:
		parts.append("%d/%d gemmes" % [Global.total_gems, gems_required])

	if not required_levels.is_empty():
		var missing_levels: Array[String] = []
		for level_id in required_levels:
			if not Global.has_completed_level(level_id):
				missing_levels.append(level_id)
		if not missing_levels.is_empty():
			parts.append("Niveaux: " + ", ".join(missing_levels))

	if parts.is_empty():
		return "VERROUILLE"
	return "VERROUILLE - " + " | ".join(parts)

func _duplicate_portal_materials() -> void:
	if portal_core.material_override:
		portal_core.material_override = portal_core.material_override.duplicate()

func _print_missing_requirements() -> void:
	if Global.total_gems < gems_required:
		print("[Portal] Gemmes requises: ", gems_required, " (actuel: ", Global.total_gems, ")")

	var missing_levels: Array[String] = []
	for level_id in required_levels:
		if not Global.has_completed_level(level_id):
			missing_levels.append(level_id)

	if not missing_levels.is_empty():
		print("[Portal] Niveaux requis non terminés: ", missing_levels)
