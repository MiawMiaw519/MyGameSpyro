extends Node3D
class_name HubWorldController

const AP_TEXTURE: Texture2D = preload("res://Assets/spyro-the-dragon-reignited/source/AP_0.png")

@onready var autumn_mesh: MeshInstance3D = $AutumnMap/tex_80

func _ready() -> void:
	_apply_ap_material()

func _apply_ap_material() -> void:
	if autumn_mesh == null:
		push_warning("[HubWorld] AutumnMap/tex_80 introuvable.")
		return

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = AP_TEXTURE
	mat.roughness = 1.0
	autumn_mesh.material_override = mat
