extends Node3D
class_name Level3Combat

const REQUIRED_ENEMIES: int = 3
const LEVEL3_CLEAR_FLAG: String = "level3_enemies_cleared"
const UNLOCK_MESSAGE_TEXT: String = "Portail boss déverrouillé !"
const UNLOCK_MESSAGE_HOLD_TIME: float = 2.2
const UNLOCK_MESSAGE_COLOR: Color = Color(1.0, 0.62, 0.18, 1.0)
const UNLOCK_MESSAGE_OUTLINE_COLOR: Color = Color(0.27, 0.12, 0.45, 1.0)

@onready var enemies_root: Node3D = $Enemies
@onready var boss_portal: LevelPortal = $BossPortal as LevelPortal

var _tracked_enemies: Array[Enemy] = []
var _is_unlocked: bool = false

var _unlock_canvas_layer: CanvasLayer
var _unlock_label: Label
var _unlock_tween: Tween

func _ready() -> void:
	_ensure_unlock_ui()

	if boss_portal == null:
		push_warning("[Level3Combat] BossPortal introuvable.")
		return

	if Global.has_completed_level(LEVEL3_CLEAR_FLAG):
		_unlock_boss_portal(false)
		return

	_lock_boss_portal()
	_register_enemies()
	_check_unlock_condition()

func _lock_boss_portal() -> void:
	boss_portal.required_levels = [LEVEL3_CLEAR_FLAG]
	boss_portal.gems_required = 0
	boss_portal.complete_level_on_enter = ""
	boss_portal.call_deferred("_refresh_visual_state")

func _register_enemies() -> void:
	_tracked_enemies.clear()

	if enemies_root == null:
		push_warning("[Level3Combat] Node Enemies introuvable.")
		return

	for child in enemies_root.get_children():
		var enemy: Enemy = child as Enemy
		if enemy == null:
			continue
		_tracked_enemies.append(enemy)
		if not enemy.died.is_connected(_on_enemy_died):
			enemy.died.connect(_on_enemy_died)

func _on_enemy_died(enemy: Enemy) -> void:
	if _tracked_enemies.has(enemy):
		_tracked_enemies.erase(enemy)
	_check_unlock_condition()

func _check_unlock_condition() -> void:
	if _is_unlocked:
		return

	var defeated_count: int = REQUIRED_ENEMIES - _tracked_enemies.size()
	if defeated_count >= REQUIRED_ENEMIES or _tracked_enemies.is_empty():
		_unlock_boss_portal(true)

func _unlock_boss_portal(show_message: bool = true) -> void:
	if _is_unlocked:
		return
	_is_unlocked = true

	boss_portal.required_levels.clear()
	boss_portal.complete_level_on_enter = ""
	boss_portal.call_deferred("_refresh_visual_state")

	Global.mark_level_completed("level3")
	Global.mark_level_completed(LEVEL3_CLEAR_FLAG)

	if show_message:
		_show_unlock_message()

	print("[Level3Combat] Les 3 ennemis sont vaincus. Portail boss débloqué.")

func _ensure_unlock_ui() -> void:
	if _unlock_canvas_layer != null:
		return

	_unlock_canvas_layer = CanvasLayer.new()
	_unlock_canvas_layer.name = "UnlockMessageLayer"
	_unlock_canvas_layer.layer = 20
	add_child(_unlock_canvas_layer)

	_unlock_label = Label.new()
	_unlock_label.name = "UnlockMessageLabel"
	_unlock_label.text = UNLOCK_MESSAGE_TEXT
	_unlock_label.visible = false
	_unlock_label.modulate = Color(UNLOCK_MESSAGE_COLOR.r, UNLOCK_MESSAGE_COLOR.g, UNLOCK_MESSAGE_COLOR.b, 0.0)
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unlock_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_unlock_label.offset_left = -360.0
	_unlock_label.offset_top = 20.0
	_unlock_label.offset_right = 360.0
	_unlock_label.offset_bottom = 98.0
	_unlock_label.add_theme_font_size_override("font_size", 42)
	_unlock_label.add_theme_color_override("font_color", UNLOCK_MESSAGE_COLOR)
	_unlock_label.add_theme_color_override("font_outline_color", UNLOCK_MESSAGE_OUTLINE_COLOR)
	_unlock_label.add_theme_constant_override("outline_size", 10)
	_unlock_label.add_theme_color_override("font_shadow_color", Color(0.17, 0.06, 0.28, 0.85))
	_unlock_label.add_theme_constant_override("shadow_offset_x", 0)
	_unlock_label.add_theme_constant_override("shadow_offset_y", 3)
	_unlock_canvas_layer.add_child(_unlock_label)

func _show_unlock_message() -> void:
	if _unlock_label == null:
		return

	if _unlock_tween and _unlock_tween.is_valid():
		_unlock_tween.kill()

	_unlock_label.text = UNLOCK_MESSAGE_TEXT
	_unlock_label.visible = true
	_unlock_label.modulate = Color(UNLOCK_MESSAGE_COLOR.r, UNLOCK_MESSAGE_COLOR.g, UNLOCK_MESSAGE_COLOR.b, 0.0)
	_unlock_label.scale = Vector2(0.93, 0.93)

	_unlock_tween = create_tween()
	_unlock_tween.tween_property(_unlock_label, "modulate:a", 1.0, 0.2)
	_unlock_tween.parallel().tween_property(_unlock_label, "scale", Vector2.ONE, 0.2)
	_unlock_tween.tween_interval(UNLOCK_MESSAGE_HOLD_TIME)
	_unlock_tween.tween_property(_unlock_label, "modulate:a", 0.0, 0.45)
	_unlock_tween.finished.connect(_on_unlock_message_finished)

func _on_unlock_message_finished() -> void:
	if _unlock_label:
		_unlock_label.visible = false
