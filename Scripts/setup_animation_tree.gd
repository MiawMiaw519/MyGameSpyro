extends Node

# Script temporaire pour créer l'AnimationTree correctement
# À exécuter une seule fois via la console Godot

func _ready() -> void:
	var spyro = get_tree().root.get_child(0).get_node("CharacterBody3D")
	var anim_tree = spyro.get_node("AnimationTree")
	var anim_player = spyro.get_node("Pivot_Modele/Sketchfab_Scene/AnimationPlayer")
	
	# Afficher toutes les animations disponibles
	print("=== Animations disponibles ===")
	for anim in anim_player.get_animation_list():
		print("- ", anim)
