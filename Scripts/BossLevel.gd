extends Node3D
class_name BossLevelController

@onready var boss: Boss = get_node_or_null("Boss") as Boss

var boss_ui: CanvasLayer
var boss_frame: Panel
var boss_name_label: Label
var boss_health_bar: ProgressBar
var boss_phase_label: Label
var boss_survival_timer_label: Label
var boss_phase_message_label: Label

var _ui_tween: Tween
var _phase_tween: Tween

func _ready() -> void:
	_ensure_boss_ui()

	if boss == null:
		push_warning("[BossLevel] Boss node introuvable, UI boss désactivée.")
		if boss_ui:
			boss_ui.visible = false
		return

	boss.health_changed.connect(_on_boss_health_changed)
	boss.boss_defeated.connect(_on_boss_defeated)
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.phase1_timer_changed.connect(_on_phase1_timer_changed)

	boss_ui.visible = true
	boss_name_label.text = "CALMARAMON"
	_on_boss_health_changed(boss.health, boss.max_health)
	_on_boss_phase_changed(int(boss.current_phase), boss.get_phase_display_text())
	_on_phase1_timer_changed(boss.get_phase1_time_remaining(), boss.phase1_survival_duration)

func _ensure_boss_ui() -> void:
	boss_ui = get_node_or_null("BossUI") as CanvasLayer
	if boss_ui == null:
		boss_ui = CanvasLayer.new()
		boss_ui.name = "BossUI"
		boss_ui.layer = 30
		add_child(boss_ui)

	boss_frame = boss_ui.get_node_or_null("TopFrame") as Panel
	if boss_frame == null:
		boss_frame = Panel.new()
		boss_frame.name = "TopFrame"
		boss_ui.add_child(boss_frame)
		boss_frame.anchor_left = 0.11
		boss_frame.anchor_top = 0.02
		boss_frame.anchor_right = 0.89
		boss_frame.anchor_bottom = 0.115
		boss_frame.modulate = Color(1.0, 1.0, 1.0, 0.96)

	boss_name_label = boss_frame.get_node_or_null("BossName") as Label
	if boss_name_label == null:
		boss_name_label = Label.new()
		boss_name_label.name = "BossName"
		boss_frame.add_child(boss_name_label)
		boss_name_label.anchor_left = 0.0
		boss_name_label.anchor_top = 0.03
		boss_name_label.anchor_right = 1.0
		boss_name_label.anchor_bottom = 0.42
		boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_name_label.add_theme_font_size_override("font_size", 24)
		boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 1.0))
		boss_name_label.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.3, 1.0))
		boss_name_label.add_theme_constant_override("outline_size", 6)

	boss_health_bar = boss_frame.get_node_or_null("BossHealthBar") as ProgressBar
	if boss_health_bar == null:
		boss_health_bar = ProgressBar.new()
		boss_health_bar.name = "BossHealthBar"
		boss_frame.add_child(boss_health_bar)
		boss_health_bar.anchor_left = 0.03
		boss_health_bar.anchor_top = 0.50
		boss_health_bar.anchor_right = 0.97
		boss_health_bar.anchor_bottom = 0.95
		boss_health_bar.custom_minimum_size = Vector2(0.0, 34.0)
		boss_health_bar.show_percentage = false

	boss_phase_label = boss_frame.get_node_or_null("BossPhase") as Label
	if boss_phase_label == null:
		boss_phase_label = Label.new()
		boss_phase_label.name = "BossPhase"
		boss_frame.add_child(boss_phase_label)
		boss_phase_label.anchor_left = 0.0
		boss_phase_label.anchor_top = 0.43
		boss_phase_label.anchor_right = 1.0
		boss_phase_label.anchor_bottom = 0.58
		boss_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_phase_label.add_theme_font_size_override("font_size", 18)
		boss_phase_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 1.0))
		boss_phase_label.add_theme_color_override("font_outline_color", Color(0.16, 0.06, 0.24, 1.0))
		boss_phase_label.add_theme_constant_override("outline_size", 4)

	boss_survival_timer_label = boss_frame.get_node_or_null("Phase1Timer") as Label
	if boss_survival_timer_label == null:
		boss_survival_timer_label = Label.new()
		boss_survival_timer_label.name = "Phase1Timer"
		boss_frame.add_child(boss_survival_timer_label)
		boss_survival_timer_label.anchor_left = 0.0
		boss_survival_timer_label.anchor_top = 0.58
		boss_survival_timer_label.anchor_right = 1.0
		boss_survival_timer_label.anchor_bottom = 0.78
		boss_survival_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_survival_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_survival_timer_label.add_theme_font_size_override("font_size", 16)
		boss_survival_timer_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55, 1.0))
		boss_survival_timer_label.add_theme_color_override("font_outline_color", Color(0.2, 0.06, 0.28, 1.0))
		boss_survival_timer_label.add_theme_constant_override("outline_size", 4)

	boss_phase_message_label = boss_ui.get_node_or_null("PhaseMessage") as Label
	if boss_phase_message_label == null:
		boss_phase_message_label = Label.new()
		boss_phase_message_label.name = "PhaseMessage"
		boss_ui.add_child(boss_phase_message_label)
		boss_phase_message_label.anchor_left = 0.15
		boss_phase_message_label.anchor_top = 0.125
		boss_phase_message_label.anchor_right = 0.85
		boss_phase_message_label.anchor_bottom = 0.185
		boss_phase_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		boss_phase_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		boss_phase_message_label.add_theme_font_size_override("font_size", 30)
		boss_phase_message_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.30, 1.0))
		boss_phase_message_label.add_theme_color_override("font_outline_color", Color(0.28, 0.08, 0.4, 1.0))
		boss_phase_message_label.add_theme_constant_override("outline_size", 7)
		boss_phase_message_label.modulate = Color(1.0, 1.0, 1.0, 0.0)

func _on_boss_health_changed(current_health: float, max_health: float) -> void:
	if boss_health_bar == null:
		return
	boss_health_bar.max_value = max_health
	boss_health_bar.value = clampf(current_health, 0.0, max_health)

func _on_boss_phase_changed(_phase: int, message: String) -> void:
	if boss_phase_label:
		boss_phase_label.text = message
	if boss_survival_timer_label:
		boss_survival_timer_label.visible = (_phase == Boss.Phase.PHASE1)
	if boss_phase_message_label == null:
		return

	boss_phase_message_label.text = message
	boss_phase_message_label.modulate.a = 0.0

	if _phase_tween and _phase_tween.is_valid():
		_phase_tween.kill()
	_phase_tween = create_tween()
	_phase_tween.tween_property(boss_phase_message_label, "modulate:a", 1.0, 0.2)
	_phase_tween.tween_interval(1.6)
	_phase_tween.tween_property(boss_phase_message_label, "modulate:a", 0.0, 0.4)

func _on_phase1_timer_changed(remaining: float, total: float) -> void:
	if boss_survival_timer_label == null:
		return
	if boss == null:
		return
	if boss.current_phase != Boss.Phase.PHASE1:
		boss_survival_timer_label.visible = false
		return

	boss_survival_timer_label.visible = true
	var sec: float = maxf(0.0, remaining)
	boss_survival_timer_label.text = "Survivez : %.1fs avant Phase 2" % sec

func _on_boss_defeated() -> void:
	if boss_ui == null:
		return
	if _ui_tween and _ui_tween.is_valid():
		_ui_tween.kill()
	_ui_tween = create_tween()
	_ui_tween.tween_property(boss_frame, "modulate:a", 0.0, 0.45)
	if boss_phase_message_label:
		_ui_tween.parallel().tween_property(boss_phase_message_label, "modulate:a", 0.0, 0.3)
	_ui_tween.finished.connect(func() -> void:
		if boss_ui:
			boss_ui.visible = false
	)
