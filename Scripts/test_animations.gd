extends Node3D

class_name TestAnimations

func _ready():
	var player = get_tree().root.find_child("CharacterBody3D", true, false)
	if player:
		print("\n=== ANIMATION TEST ===")
		print("Player found: ", player.name)
		
		# Check AnimationPlayer
		var pivot = player.get_node_or_null("Pivot_Modele")
		if pivot:
			var sketchfab = pivot.get_node_or_null("Sketchfab_Scene")
			if sketchfab:
				var anim_player = sketchfab.get_node_or_null("AnimationPlayer")
				if anim_player:
					print("✓ AnimationPlayer found!")
					var animations = anim_player.get_animation_list()
					print("Available animations: ", animations.size())
					for anim in animations:
						print("  - ", anim)
					
					# Check if configured animations exist
					print("\nChecking configured animations:")
					var configured = {
						"idle": player.idle_animation_name,
						"walk": player.walk_animation_name,
						"run": player.run_animation_name,
						"jump": player.jump_animation_name,
						"charge": player.charge_animation_name,
						"flame": player.flame_animation_name
					}
					
					for state_name in configured:
						var anim_name = configured[state_name]
						if anim_name in animations:
							print("  ✓ ", state_name, " (", anim_name, ")")
						else:
							print("  ✗ ", state_name, " (", anim_name, ") - NOT FOUND")
				else:
					print("✗ AnimationPlayer not found!")
			else:
				print("✗ Sketchfab_Scene not found!")
		else:
			print("✗ Pivot_Modele not found!")
		
		# Check other systems
		print("\nOther Systems:")
		print("  - Stamina: ", player.current_stamina, "/", player.max_stamina)
		print("  - State: ", player.current_state)
		print("  - Can Glide: ", player.can_glide)
	else:
		print("ERROR: CharacterBody3D (Player) not found!")
