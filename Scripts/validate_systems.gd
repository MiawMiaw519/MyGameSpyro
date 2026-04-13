extends Node3D

## Validation Script - Vérifie que tous les systèmes sont configurés correctement

func _ready():
	print("\n" + "=".repeat(60))
	print("VALIDATION DES SYSTEMES DU JEU")
	print("=".repeat(60) + "\n")
	
	var issues = []
	var warnings = []
	
	# 1. Verifier le joueur
	var player = get_tree().root.find_child("CharacterBody3D", true, false)
	if not player:
		issues.append("[ERREUR] CharacterBody3D (Player) non trouve!")
	else:
		print("[OK] Joueur trouve: ", player.name)
		
		# Verifier l'AnimationPlayer
		var pivot = player.get_node_or_null("Pivot_Modele")
		if not pivot:
			issues.append("  [ERREUR] Pivot_Modele non trouve!")
		else:
			var sketchfab = pivot.get_node_or_null("Sketchfab_Scene")
			if not sketchfab:
				issues.append("  [ERREUR] Sketchfab_Scene non trouve!")
			else:
				var anim_player = sketchfab.get_node_or_null("AnimationPlayer")
				if not anim_player:
					issues.append("  [ERREUR] AnimationPlayer non trouve!")
				else:
					print("  [OK] AnimationPlayer trouve")
					
					# Verifier les animations configurees
					var anims = anim_player.get_animation_list()
					print("	 Animations disponibles: ", anims.size())
					
					var configured = [
						["idle", player.idle_animation_name],
						["walk", player.walk_animation_name],
						["run", player.run_animation_name],
						["jump", player.jump_animation_name],
						["charge", player.charge_animation_name],
						["flame", player.flame_animation_name]
					]
					
					for config in configured:
						var state = config[0]
						var anim_name = config[1]
						if anim_name == "":
							issues.append("  [ERREUR] Animation '" + state + "' non configuree (vide)")
						elif not (anim_name in anims):
							issues.append("  [ERREUR] Animation '" + state + "' (" + anim_name + ") n'existe pas!")
						else:
							print("	 [OK] " + state + ": " + anim_name)
		
		# Verifier la stamina
		if player.max_stamina <= 0:
			issues.append("  [ERREUR] max_stamina invalide")
		else:
			print("  [OK] Stamina: " + str(int(player.current_stamina)) + "/" + str(int(player.max_stamina)))
		
		# Verifier la EnduranceBar
		var endurance_bar = player.get_node_or_null("../CanvasLayer/EnduranceBar")
		if not endurance_bar:
			warnings.append("  [ALERTE] EnduranceBar non trouvee")
		else:
			print("  [OK] EnduranceBar trouvee")
		
		# Verifier le FlameArea
		var flame_area = player.get_node_or_null("Pivot_Modele/FlameArea")
		if not flame_area:
			issues.append("  [ERREUR] FlameArea non trouvee!")
		else:
			print("  [OK] FlameArea trouvee")
	
	# 2. Verifier Global
	print("\n[OK] Systeme Global:")
	print("   Gems totales: ", Global.total_gems)
	print("   Checkpoint: ", Global.has_checkpoint)
	
	# 3. Verifier les Portals
	var portals = get_tree().root.find_children("Portal*", "Area3D", false)
	print("\n[OK] Portails trouves: ", portals.size())
	for portal in portals:
		if portal.has_meta("script"):
			print("   - ", portal.name, " (gems requis: ", portal.gems_required, ")")
	
	# 4. Affichage des resultats
	print("\n" + "=".repeat(60))
	if issues.is_empty() and warnings.is_empty():
		print("[OK] TOUS LES SYSTEMES SONT CORRECTEMENT CONFIGURES!")
	else:
		if not issues.is_empty():
			print("[ERREURS] PROBLEMES DETECTES:")
			for issue in issues:
				print("  " + issue)
		if not warnings.is_empty():
			print("\n[ALERTES] AVERTISSEMENTS:")
			for warning in warnings:
				print("  " + warning)
	print("=".repeat(60) + "\n")
