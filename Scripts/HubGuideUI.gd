extends CanvasLayer
class_name HubGuideUI

@onready var objective_label: Label = $ObjectiveLabel

func _ready() -> void:
	if Global.gems_changed.is_connected(_on_gems_changed) == false:
		Global.gems_changed.connect(_on_gems_changed)
	if Global.level_completed.is_connected(_on_level_completed) == false:
		Global.level_completed.connect(_on_level_completed)
	_refresh_text()

func _exit_tree() -> void:
	if Global.gems_changed.is_connected(_on_gems_changed):
		Global.gems_changed.disconnect(_on_gems_changed)
	if Global.level_completed.is_connected(_on_level_completed):
		Global.level_completed.disconnect(_on_level_completed)

func _on_gems_changed(_new_amount: int) -> void:
	_refresh_text()

func _on_level_completed(_level_id: String) -> void:
	_refresh_text()

func _refresh_text() -> void:
	var l1_done: bool = Global.has_completed_level("level1")
	var l2_done: bool = Global.has_completed_level("level2")
	var l3_done: bool = Global.has_completed_level("level3")
	var all_done: bool = Global.has_completed_all(["level1", "level2", "level3"])

	var can_l2: bool = Global.total_gems >= 50
	var can_l3: bool = Global.total_gems >= 150

	var line_l1: String = "Niveau 1 (Portail centre): OUVERT"
	var line_l2: String = "Niveau 2 (Portail droite): %s" % ("OUVERT" if can_l2 else "VERROUILLE - 50 gemmes")
	var line_l3: String = "Niveau 3 (Portail gauche): %s" % ("OUVERT" if can_l3 else "VERROUILLE - 150 gemmes")
	var line_boss: String = "Boss (Portail final): %s" % ("OUVERT" if all_done else "VERROUILLE - finir N1/N2/N3")

	var status_l1: String = "N1 termine: %s" % ("Oui" if l1_done else "Non")
	var status_l2: String = "N2 termine: %s" % ("Oui" if l2_done else "Non")
	var status_l3: String = "N3 termine: %s" % ("Oui" if l3_done else "Non")

	objective_label.text = "HUB - OBJECTIF\nGemmes: %d\n\n%s\n%s\n%s\n%s\n\n%s | %s | %s\n\nConseil: Ramasse les gemmes brillantes dans le HUB et dans les niveaux." % [
		Global.total_gems,
		line_l1,
		line_l2,
		line_l3,
		line_boss,
		status_l1,
		status_l2,
		status_l3
	]
